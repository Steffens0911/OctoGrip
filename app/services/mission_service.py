import logging
from uuid import UUID

from sqlalchemy import exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.app_time import today_in_app_tz
from app.core.graduation import points_for_graduation
from app.core.points_limits import MIN_REWARD_POINTS, clamp_reward_points
from app.models import Academy, Lesson, Mission, MissionUsage, Technique, TechniqueExecution
from app.schemas.mission import (
    MissionTodayResponse,
    MissionWeekResponse,
    MissionWeekSlotResponse,
    WeeklyKitOptionResponse,
)
from app.services.academy_service import ensure_weekly_missions_if_needed

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
    today = today_in_app_tz()
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
            (
                await db.execute(
                    select(Mission)
                    .where(
                        Mission.is_active.is_(True),
                        Mission.academy_id == academy_id,
                        Mission.level == level_normalized,
                        Mission.slot_index.isnot(None),
                        Mission.weekly_kit_id.is_(None),
                        Mission.deleted_at.is_(None),
                    )
                    .options(*options)
                    .order_by(Mission.slot_index.asc())
                )
            )
            .unique()
            .scalars()
            .first()
        )
    if mission is None:
        mission = (
            (
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
            )
            .unique()
            .scalars()
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
        video_url = (
            (lesson.video_url or "").strip() or (lesson.technique_video_url or "").strip() or _get_video_url(technique)
        )
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
        display_multiplier if display_multiplier is not None else getattr(mission, "multiplier", MIN_REWARD_POINTS)
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

    _user_row = (
        (await db.execute(select(User.academy_id, User.graduation).where(User.id == user_id))).one_or_none()
        if user_id
        else None
    )
    resolved_academy_id = academy_id
    if resolved_academy_id is None and _user_row and _user_row[0] is not None:
        resolved_academy_id = _user_row[0]

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
    grad_mult = max(1, points_for_graduation(_user_row[1]) if _user_row else 1)
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


async def _get_mission_week_kit_response(
    db: AsyncSession,
    *,
    level_n: str,
    user_id: UUID | None,
    resolved_academy_id: UUID,
    academy: Academy | None,
    options,
) -> MissionWeekResponse:
    from app.services.weekly_kit_service import (
        ensure_kit_missions_from_db_items,
        get_kit,
        get_user_kit_choice,
        list_active_kits_for_academy,
    )
    from app.utils.iso_week import iso_week_key_for_date

    kits = await list_active_kits_for_academy(db, resolved_academy_id)
    available: list[WeeklyKitOptionResponse] = []
    for k in kits:
        n_items = len(k.items or [])
        if 1 <= n_items <= 5:
            available.append(WeeklyKitOptionResponse(kit_id=k.id, label=k.label, item_count=n_items))
    iso_y, iso_w = iso_week_key_for_date()
    selected_kit_id: UUID | None = None
    if user_id is not None:
        ch = await get_user_kit_choice(db, user_id, resolved_academy_id, iso_y, iso_w)
        if ch:
            selected_kit_id = ch.kit_id
    if selected_kit_id is None:
        return MissionWeekResponse(
            entries=[],
            needs_kit_choice=True,
            available_kits=available,
            selected_kit_id=None,
        )

    await ensure_kit_missions_from_db_items(db, resolved_academy_id, selected_kit_id)
    kit_row = await get_kit(db, selected_kit_id, resolved_academy_id)
    kit_label = kit_row.label if kit_row else None

    missions = (
        (
            await db.execute(
                select(Mission)
                .where(
                    Mission.is_active.is_(True),
                    Mission.academy_id == resolved_academy_id,
                    Mission.level == level_n,
                    Mission.weekly_kit_id == selected_kit_id,
                    Mission.slot_index.in_((0, 1, 2, 3, 4)),
                    Mission.deleted_at.is_(None),
                )
                .options(*options)
                .order_by(Mission.slot_index.asc())
            )
        )
        .unique()
        .scalars()
        .all()
    )
    missions_by_slot: dict[int, Mission] = {}
    for m in missions:
        if m.technique and m.slot_index is not None:
            missions_by_slot[m.slot_index] = m
    ordered_slots = sorted(missions_by_slot.keys())
    completed_mission_ids: set[UUID] = set()
    if user_id is not None and ordered_slots:
        mission_ids = [missions_by_slot[s].id for s in ordered_slots]
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

    entries: list[MissionWeekSlotResponse] = []
    for si in ordered_slots:
        mission = missions_by_slot[si]
        period_label = f"Foco {si + 1}"
        weekly_theme = kit_label or mission.theme
        if academy and academy.weekly_theme and not kit_label:
            weekly_theme = academy.weekly_theme
        payload = await _mission_to_today_response(
            mission,
            weekly_theme=weekly_theme,
            db=None,
            user_id=user_id,
            already_completed_override=mission.id in completed_mission_ids,
        )
        entries.append(MissionWeekSlotResponse(period_label=period_label, mission=payload))

    return MissionWeekResponse(
        entries=entries,
        needs_kit_choice=False,
        available_kits=available,
        selected_kit_id=selected_kit_id,
    )


async def get_mission_week_response(
    db: AsyncSession,
    level: str = "beginner",
    user_id: UUID | None = None,
    academy_id: UUID | None = None,
) -> MissionWeekResponse:
    """
    Semana do aluno: modo **turmas** (escolha + focos 1–N) se a academia tiver turma ativa;
    caso contrário, até 3 missões legadas por slots 0–2.
    """
    from app.models import User
    from app.services.weekly_kit_service import academy_has_active_weekly_kits

    user = None
    if user_id:
        user = (
            (
                await db.execute(
                    select(User)
                    .options(selectinload(User.academy).selectinload(Academy.weekly_technique))
                    .where(User.id == user_id)
                )
            )
            .unique()
            .scalars()
            .first()
        )
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
                (
                    await db.execute(
                        select(Academy)
                        .where(Academy.id == resolved_academy_id)
                        .options(selectinload(Academy.weekly_technique))
                    )
                )
                .unique()
                .scalars()
                .first()
            )
        if await academy_has_active_weekly_kits(db, resolved_academy_id):
            return await _get_mission_week_kit_response(
                db,
                level_n=level_n,
                user_id=user_id,
                resolved_academy_id=resolved_academy_id,
                academy=academy,
                options=options,
            )
        all_missions = (
            (
                await db.execute(
                    select(Mission)
                    .where(
                        Mission.is_active.is_(True),
                        Mission.academy_id == resolved_academy_id,
                        Mission.level == level_n,
                        Mission.slot_index.in_((0, 1, 2)),
                        Mission.weekly_kit_id.is_(None),
                        Mission.deleted_at.is_(None),
                    )
                    .options(*options)
                )
            )
            .unique()
            .scalars()
            .all()
        )
        need_ensure = (
            academy is not None
            and (academy.weekly_technique_id or academy.weekly_technique_2_id or academy.weekly_technique_3_id)
            and sum(1 for m in all_missions if m.technique) < 3
        )
        if need_ensure:
            await ensure_weekly_missions_if_needed(db, resolved_academy_id, academy=academy)
            all_missions = (
                (
                    await db.execute(
                        select(Mission)
                        .where(
                            Mission.is_active.is_(True),
                            Mission.academy_id == resolved_academy_id,
                            Mission.level == level_n,
                            Mission.slot_index.in_((0, 1, 2)),
                            Mission.weekly_kit_id.is_(None),
                            Mission.deleted_at.is_(None),
                        )
                        .options(*options)
                    )
                )
                .unique()
                .scalars()
                .all()
            )
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
    return MissionWeekResponse(
        entries=entries,
        needs_kit_choice=False,
        available_kits=[],
        selected_kit_id=None,
    )
