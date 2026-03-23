import logging
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy import or_, exists, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.points_limits import MIN_REWARD_POINTS, clamp_reward_points
from app.models import Academy, Lesson, Mission, MissionUsage, Technique, TechniqueExecution
from app.services.academy_service import ensure_weekly_missions_if_needed
from app.schemas.mission import (
    MissionTodayResponse,
    MissionWeekResponse,
    MissionWeekSlotResponse,
)

logger = logging.getLogger(__name__)


async def get_today_mission(
    db: AsyncSession,
    level: str = "beginner",
    academy_id: UUID | None = None,
) -> Mission | None:
    """
    Retorna a missão ativa para o nível (e opcionalmente academia).
    Academia: busca por slot_index (0, 1, 2); sem datas. Global/legado: start_date/end_date.
    """
    today = date.today()
    level_normalized = (level or "beginner").lower().strip()
    if level_normalized not in ("beginner", "intermediate"):
        level_normalized = "beginner"

    options = (
        selectinload(Mission.technique).selectinload(Technique.lessons),
        selectinload(Mission.lesson).selectinload(Lesson.technique),
    )

    mission = None
    if academy_id is not None:
        mission = (
            await db.execute(
                select(Mission)
                .where(
                    Mission.is_active.is_(True),
                    Mission.academy_id == academy_id,
                    Mission.level == level_normalized,
                    Mission.slot_index.isnot(None),
                    Mission.deleted_at.is_(None),
                )
                .options(*options)
                .order_by(Mission.slot_index.asc())
            )
        ).unique().scalars().first()
    if mission is None:
        mission = (
            await db.execute(
                select(Mission)
                .where(
                    Mission.is_active.is_(True),
                    Mission.academy_id.is_(None),
                    Mission.level == level_normalized,
                    Mission.start_date.isnot(None),
                    Mission.end_date.isnot(None),
                    Mission.start_date <= today,
                    Mission.end_date >= today,
                    Mission.deleted_at.is_(None),
                )
                .options(*options)
                .order_by(Mission.start_date.asc())
            )
        ).unique().scalars().first()

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


async def _mission_to_today_response(
    mission: Mission,
    mission_title: str = "Missão do dia",
    weekly_theme: str | None = None,
    is_review: bool = False,
    *,
    db: AsyncSession | None = None,
    user_id: UUID | None = None,
    display_multiplier: int | None = None,
    already_completed_override: bool | None = None,
) -> MissionTodayResponse:
    """Monta MissionTodayResponse. Se mission.lesson existe, usa a lição (missão = mesma coisa que a lição)."""
    technique = mission.technique
    lesson = mission.lesson

    if lesson is not None:
        lesson_title = lesson.title
        description = (lesson.content or "").strip() or (technique.description or "")
        video_url = (lesson.video_url or "").strip() or (lesson.technique_video_url or "").strip() or _get_video_url(technique)
        position_name = lesson.position_name or ""
        lesson_id = lesson.id
    else:
        lesson_title = technique.name
        description = technique.description or ""
        position_name = ""
        video_url = _get_video_url(technique)
        lesson_id = None
        if technique.lessons:
            first_lesson = min(technique.lessons, key=lambda L: L.order_index)
            lesson_id = first_lesson.id

    if already_completed_override is not None:
        already_completed = already_completed_override
    else:
        already_completed = False
        if db is not None and user_id is not None:
            stmt = select(
                or_(
                    exists()
                    .select_from(MissionUsage)
                    .where(
                        MissionUsage.user_id == user_id,
                        MissionUsage.mission_id == mission.id,
                    ),
                    exists()
                    .select_from(TechniqueExecution)
                    .where(
                        TechniqueExecution.user_id == user_id,
                        TechniqueExecution.mission_id == mission.id,
                        TechniqueExecution.status == "confirmed",
                    ),
                )
            )
            already_completed = (await db.execute(stmt)).scalar() or False
    raw_mult = (
        display_multiplier
        if display_multiplier is not None
        else getattr(mission, "multiplier", MIN_REWARD_POINTS)
    )
    mult = clamp_reward_points(raw_mult or MIN_REWARD_POINTS)
    return MissionTodayResponse(
        mission_id=mission.id,
        technique_id=technique.id,
        lesson_id=lesson_id,
        mission_title=mission_title,
        lesson_title=lesson_title,
        description=description,
        video_url=video_url,
        position_name=position_name,
        technique_name=technique.name,
        objective=technique.description,
        estimated_duration_seconds=None,
        weekly_theme=weekly_theme,
        is_review=is_review,
        already_completed=already_completed,
        multiplier=mult,
    )


async def get_mission_today_response(
    db: AsyncSession,
    level: str = "beginner",
    user_id: UUID | None = None,
    review_after_days: int = 7,
    academy_id: UUID | None = None,
) -> MissionTodayResponse | None:
    """
    Retorna o payload da missão do dia (técnica + posição). mission_id para conclusão por missão.
    A-02: academy_id (ou do user) define missão da academia; fallback em missão global.
    """
    from app.models import User

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none() if user_id else None
    resolved_academy_id = academy_id
    if resolved_academy_id is None and user and user.academy_id is not None:
        resolved_academy_id = user.academy_id

    mission = await get_today_mission(db, level=level, academy_id=resolved_academy_id)
    if mission and mission.technique:
        weekly_theme = mission.theme
        if resolved_academy_id:
            academy = (await db.execute(select(Academy).where(Academy.id == resolved_academy_id))).scalar_one_or_none()
            if academy:
                if academy.weekly_technique and academy.weekly_technique.name:
                    weekly_theme = academy.weekly_technique.name
                elif academy.weekly_theme:
                    weekly_theme = academy.weekly_theme
        logger.info(
            "get_mission_today_response",
            extra={"source": "mission", "mission_id": str(mission.id), "technique_id": str(mission.technique_id)},
        )
        return await _mission_to_today_response(
            mission,
            weekly_theme=weekly_theme,
            db=db,
            user_id=user_id,
        )

    logger.warning("get_mission_today_response using_fallback", extra={"reason": "no_mission_today"})
    # Corrigir full table scan: adicionar WHERE e ordenação determinística
    # Se academy_id fornecido, filtrar por academy; senão, pegar primeira técnica ordenada por nome
    stmt = (
        select(Technique)
        .options(
            selectinload(Technique.lessons),
        )
        .where(Technique.deleted_at.is_(None))
        .order_by(Technique.name.asc())
    )
    if academy_id is not None:
        stmt = stmt.where(Technique.academy_id == academy_id)
    technique = (await db.execute(stmt)).unique().scalars().first()
    if not technique:
        logger.info("get_mission_today_response", extra={"found": False})
        return None
    position_name = ""
    grad_mult = max(1, points_for_graduation(user.graduation) if user else 1)
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
        multiplier=grad_mult,
    )


async def get_mission_week_response(
    db: AsyncSession,
    level: str = "beginner",
    user_id: UUID | None = None,
    academy_id: UUID | None = None,
) -> MissionWeekResponse:
    """
    Retorna as 3 missões para a academia do usuário.
    Missões persistem enquanto configuradas (sem rotação por dias).
    """
    from app.models import User

    user = None
    if user_id:
        user = (
            await db.execute(
                select(User)
                .options(selectinload(User.academy).selectinload(Academy.weekly_technique))
                .where(User.id == user_id)
            )
        ).unique().scalars().first()
    resolved_academy_id = academy_id or (user.academy_id if user else None)

    level_n = (level or "beginner").lower().strip()
    if level_n not in ("beginner", "intermediate"):
        level_n = "beginner"

    options = (
        selectinload(Mission.technique).selectinload(Technique.lessons),
        selectinload(Mission.lesson).selectinload(Lesson.technique),
    )

    entries: list[MissionWeekSlotResponse] = []
    period_labels = ["Missão 1", "Missão 2", "Missão 3"]

    missions_by_slot: dict[int, Mission] = {}
    academy = None
    if resolved_academy_id is not None:
        if user and user.academy_id == resolved_academy_id and user.academy is not None:
            academy = user.academy
        else:
            academy = (
                await db.execute(
                    select(Academy)
                    .where(Academy.id == resolved_academy_id)
                    .options(selectinload(Academy.weekly_technique))
                )
            ).unique().scalars().first()
        all_missions = (
            await db.execute(
                select(Mission)
                .where(
                    Mission.is_active.is_(True),
                    Mission.academy_id == resolved_academy_id,
                    Mission.level == level_n,
                    Mission.slot_index.in_((0, 1, 2)),
                    Mission.deleted_at.is_(None),
                )
                .options(*options)
            )
        ).unique().scalars().all()
        need_ensure = (
            academy is not None
            and (academy.weekly_technique_id or academy.weekly_technique_2_id or academy.weekly_technique_3_id)
            and sum(1 for m in all_missions if m.technique) < 3
        )
        if need_ensure:
            await ensure_weekly_missions_if_needed(db, resolved_academy_id, academy=academy)
            all_missions = (
                await db.execute(
                    select(Mission)
                    .where(
                        Mission.is_active.is_(True),
                        Mission.academy_id == resolved_academy_id,
                        Mission.level == level_n,
                        Mission.slot_index.in_((0, 1, 2)),
                        Mission.deleted_at.is_(None),
                    )
                    .options(*options)
                )
            ).unique().scalars().all()
        missions_by_slot = {m.slot_index: m for m in all_missions if m.technique}

    completed_mission_ids: set[UUID] = set()
    if user_id is not None and missions_by_slot:
        mission_ids = [m.id for m in missions_by_slot.values()]
        usages = (
            await db.execute(
                select(MissionUsage.mission_id).where(
                    MissionUsage.user_id == user_id,
                    MissionUsage.mission_id.in_(mission_ids),
                )
            )
        ).all()
        for (mid,) in usages:
            completed_mission_ids.add(mid)
        execs = (
            await db.execute(
                select(TechniqueExecution.mission_id).where(
                    TechniqueExecution.user_id == user_id,
                    TechniqueExecution.mission_id.in_(mission_ids),
                    TechniqueExecution.status == "confirmed",
                )
            )
        ).all()
        for (mid,) in execs:
            completed_mission_ids.add(mid)

    for slot_idx, period_label in enumerate(period_labels):
        mission = missions_by_slot.get(slot_idx)
        if mission and mission.technique:
            logger.debug(
                "get_mission_week_response slot_found",
                extra={
                    "slot": slot_idx + 1,
                    "period_label": period_label,
                    "mission_id": str(mission.id),
                    "technique": mission.technique.name if mission.technique else None,
                },
            )
            weekly_theme = mission.theme
            if academy:
                if slot_idx == 0 and academy.weekly_technique and academy.weekly_technique.name:
                    weekly_theme = academy.weekly_technique.name
                elif academy.weekly_theme:
                    weekly_theme = academy.weekly_theme
            payload = await _mission_to_today_response(
                mission,
                weekly_theme=weekly_theme,
                db=None,
                user_id=user_id,
                already_completed_override=mission.id in completed_mission_ids,
            )
            entries.append(MissionWeekSlotResponse(period_label=period_label, mission=payload))
        else:
            logger.debug(
                "get_mission_week_response slot_empty",
                extra={"slot": slot_idx + 1, "period_label": period_label},
            )
            entries.append(MissionWeekSlotResponse(period_label=period_label, mission=None))
    missions_count = sum(1 for e in entries if e.mission is not None)
    logger.debug(
        "get_mission_week_response",
        extra={
            "user_id": str(user_id) if user_id else None,
            "academy_id": str(resolved_academy_id) if resolved_academy_id else None,
            "level": level_n,
            "missions_found": missions_count,
        },
    )
    return MissionWeekResponse(entries=entries)
