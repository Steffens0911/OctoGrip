import logging
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.models import Academy, Mission, MissionUsage, Technique
from app.schemas.mission import (
    MissionTodayResponse,
    MissionWeekResponse,
    MissionWeekSlotResponse,
)

logger = logging.getLogger(__name__)


def get_today_mission(
    db: Session,
    level: str = "beginner",
    academy_id: UUID | None = None,
) -> Mission | None:
    """
    Retorna a missão ativa para o nível (e opcionalmente academia).
    A-02: Se academy_id for informado, busca primeiro missão da academia; senão, global (academy_id IS NULL).
    """
    today = date.today()
    level_normalized = (level or "beginner").lower().strip()
    if level_normalized not in ("beginner", "intermediate"):
        level_normalized = "beginner"

    base_filter = (
        Mission.is_active.is_(True),
        Mission.start_date <= today,
        Mission.end_date >= today,
        Mission.level == level_normalized,
    )
    options = (
        joinedload(Mission.technique).joinedload(Technique.from_position),
        joinedload(Mission.technique).joinedload(Technique.to_position),
        joinedload(Mission.technique).joinedload(Technique.lessons),
    )

    mission = None
    if academy_id is not None:
        mission = (
            db.query(Mission)
            .filter(*base_filter, Mission.academy_id == academy_id)
            .options(*options)
            .order_by(Mission.start_date.asc())
            .first()
        )
    if mission is None:
        mission = (
            db.query(Mission)
            .filter(*base_filter, Mission.academy_id.is_(None))
            .options(*options)
            .order_by(Mission.start_date.asc())
            .first()
        )

    if mission:
        logger.info(
            "get_today_mission",
            extra={
                "mission_id": str(mission.id),
                "technique_id": str(mission.technique_id),
                "level": level_normalized,
                "academy_id": str(academy_id) if academy_id else None,
            },
        )
    else:
        logger.info("get_today_mission", extra={"found": False, "level": level_normalized})
    return mission


def _get_video_url(technique: Technique) -> str:
    """Retorna video_url da técnica ou da primeira lição com vídeo (ordenada por order_index)."""
    url = (technique.video_url or "").strip()
    if url:
        return url
    lessons = sorted(technique.lessons or [], key=lambda L: L.order_index)
    for lesson in lessons:
        if lesson.video_url and lesson.video_url.strip():
            return lesson.video_url.strip()
    return ""


def _mission_to_today_response(
    mission: Mission,
    mission_title: str = "Missão do dia",
    weekly_theme: str | None = None,
    is_review: bool = False,
    *,
    db: Session | None = None,
    user_id: UUID | None = None,
) -> MissionTodayResponse:
    """Monta MissionTodayResponse a partir de Mission (technique e posições já carregados)."""
    technique = mission.technique
    description = technique.description or ""
    position_name = f"da posição {technique.from_position.name} → para posição {technique.to_position.name}"
    video_url = _get_video_url(technique)
    already_completed = False
    if db is not None and user_id is not None:
        already_completed = (
            db.query(MissionUsage)
            .filter(
                MissionUsage.user_id == user_id,
                MissionUsage.mission_id == mission.id,
            )
            .first()
            is not None
        )
    return MissionTodayResponse(
        mission_id=mission.id,
        technique_id=technique.id,
        lesson_id=None,
        mission_title=mission_title,
        lesson_title=technique.name,
        description=description,
        video_url=video_url,
        position_name=position_name,
        technique_name=technique.name,
        objective=technique.description,
        estimated_duration_seconds=None,
        weekly_theme=weekly_theme,
        is_review=is_review,
        already_completed=already_completed,
    )


def get_mission_today_response(
    db: Session,
    level: str = "beginner",
    user_id: UUID | None = None,
    review_after_days: int = 7,
    academy_id: UUID | None = None,
) -> MissionTodayResponse | None:
    """
    Retorna o payload da missão do dia (técnica + posição). mission_id para conclusão por missão.
    A-02: academy_id (ou do user) define missão da academia; fallback em missão global.
    """
    resolved_academy_id = academy_id
    if resolved_academy_id is None and user_id is not None:
        from app.models import User

        user = db.query(User).filter(User.id == user_id).first()
        if user and user.academy_id is not None:
            resolved_academy_id = user.academy_id

    mission = get_today_mission(db, level=level, academy_id=resolved_academy_id)
    if mission and mission.technique:
        weekly_theme = mission.theme
        if resolved_academy_id:
            academy = db.query(Academy).filter(Academy.id == resolved_academy_id).first()
            if academy:
                if academy.weekly_technique and academy.weekly_technique.name:
                    weekly_theme = academy.weekly_technique.name
                elif academy.weekly_theme:
                    weekly_theme = academy.weekly_theme
        logger.info(
            "get_mission_today_response",
            extra={"source": "mission", "mission_id": str(mission.id), "technique_id": str(mission.technique_id)},
        )
        return _mission_to_today_response(
            mission, weekly_theme=weekly_theme, db=db, user_id=user_id
        )

    logger.warning("get_mission_today_response using_fallback", extra={"reason": "no_mission_today"})
    technique = (
        db.query(Technique)
        .options(
            joinedload(Technique.from_position),
            joinedload(Technique.to_position),
            joinedload(Technique.lessons),
        )
        .first()
    )
    if not technique:
        logger.info("get_mission_today_response", extra={"found": False})
        return None
    position_name = f"da posição {technique.from_position.name} → para posição {technique.to_position.name}"
    return MissionTodayResponse(
        mission_id=None,
        technique_id=technique.id,
        lesson_id=None,
        mission_title="Missão do dia",
        lesson_title=technique.name,
        description=technique.description or "",
        video_url=_get_video_url(technique),
        position_name=position_name,
        technique_name=technique.name,
        objective=technique.description,
        estimated_duration_seconds=None,
        weekly_theme=None,
        is_review=False,
        already_completed=False,
    )


def get_mission_week_response(
    db: Session,
    level: str = "beginner",
    user_id: UUID | None = None,
    academy_id: UUID | None = None,
) -> MissionWeekResponse:
    """
    Retorna as 3 missões da semana para a academia do usuário.
    Se só técnica 1 estiver configurada: missão apenas no slot 1; slots 2 e 3 vazios.
    Se 2 ou 3 técnicas: busca por intervalo de datas (seg-ter, qua-qui, sex-dom).
    """
    from app.models import User

    resolved_academy_id = academy_id
    if resolved_academy_id is None and user_id is not None:
        user = db.query(User).filter(User.id == user_id).first()
        if user and user.academy_id is not None:
            resolved_academy_id = user.academy_id

    level_n = (level or "beginner").lower().strip()
    if level_n not in ("beginner", "intermediate"):
        level_n = "beginner"

    today = date.today()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)
    options = (
        joinedload(Mission.technique).joinedload(Technique.from_position),
        joinedload(Mission.technique).joinedload(Technique.to_position),
        joinedload(Mission.technique).joinedload(Technique.lessons),
    )

    # Se só técnica 1 está configurada, a missão é da semana inteira: mostrar só no slot 1
    only_first_slot = False
    if resolved_academy_id is not None:
        academy = db.query(Academy).filter(Academy.id == resolved_academy_id).first()
        if academy and academy.weekly_technique_2_id is None and academy.weekly_technique_3_id is None:
            only_first_slot = True

    entries: list[MissionWeekSlotResponse] = []
    if only_first_slot:
        # Slot 1: missão da semana inteira (se existir); slots 2 e 3: vazios
        mission = None
        if resolved_academy_id is not None:
            mission = (
                db.query(Mission)
                .filter(
                    Mission.is_active.is_(True),
                    Mission.academy_id == resolved_academy_id,
                    Mission.level == level_n,
                    Mission.start_date <= week_end,
                    Mission.end_date >= week_start,
                )
                .options(*options)
                .order_by(Mission.start_date.asc())
                .first()
            )
        if mission is None:
            mission = (
                db.query(Mission)
                .filter(
                    Mission.is_active.is_(True),
                    Mission.academy_id.is_(None),
                    Mission.level == level_n,
                    Mission.start_date <= week_end,
                    Mission.end_date >= week_start,
                )
                .options(*options)
                .order_by(Mission.start_date.asc())
                .first()
            )
        for i, period_label in enumerate(["Missão 1", "Missão 2", "Missão 3"]):
            if i == 0 and mission and mission.technique:
                weekly_theme = mission.theme
                academy = db.query(Academy).filter(Academy.id == resolved_academy_id).first()
                if academy:
                    if academy.weekly_technique and academy.weekly_technique.name:
                        weekly_theme = academy.weekly_technique.name
                    elif academy.weekly_theme:
                        weekly_theme = academy.weekly_theme
                payload = _mission_to_today_response(
                    mission, weekly_theme=weekly_theme, db=db, user_id=user_id
                )
                entries.append(MissionWeekSlotResponse(period_label=period_label, mission=payload))
            else:
                entries.append(MissionWeekSlotResponse(period_label=period_label, mission=None))
    else:
        # 2 ou 3 técnicas: busca por slot (intervalo de datas)
        slots = [
            (week_start, week_start + timedelta(days=1), "Missão 1"),
            (week_start + timedelta(days=2), week_start + timedelta(days=3), "Missão 2"),
            (week_start + timedelta(days=4), week_start + timedelta(days=6), "Missão 3"),
        ]
        for slot_start, slot_end, period_label in slots:
            mission = None
            if resolved_academy_id is not None:
                mission = (
                    db.query(Mission)
                    .filter(
                        Mission.is_active.is_(True),
                        Mission.academy_id == resolved_academy_id,
                        Mission.level == level_n,
                        Mission.start_date <= slot_end,
                        Mission.end_date >= slot_start,
                    )
                    .options(*options)
                    .order_by(Mission.start_date.asc())
                    .first()
                )
            if mission is None:
                mission = (
                    db.query(Mission)
                    .filter(
                        Mission.is_active.is_(True),
                        Mission.academy_id.is_(None),
                        Mission.level == level_n,
                        Mission.start_date <= slot_end,
                        Mission.end_date >= slot_start,
                    )
                    .options(*options)
                    .order_by(Mission.start_date.asc())
                    .first()
                )
            if mission and mission.technique:
                weekly_theme = mission.theme
                if resolved_academy_id:
                    academy = db.query(Academy).filter(Academy.id == resolved_academy_id).first()
                    if academy:
                        if academy.weekly_technique and academy.weekly_technique.name:
                            weekly_theme = academy.weekly_technique.name
                        elif academy.weekly_theme:
                            weekly_theme = academy.weekly_theme
                payload = _mission_to_today_response(
                    mission, weekly_theme=weekly_theme, db=db, user_id=user_id
                )
                entries.append(MissionWeekSlotResponse(period_label=period_label, mission=payload))
            else:
                entries.append(MissionWeekSlotResponse(period_label=period_label, mission=None))
    return MissionWeekResponse(entries=entries)
