"""Turmas semanais (1–5 técnicas; rótulo = nome da turma) e escolha do aluno por semana ISO."""
from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import delete as sa_delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AppError, NotFoundError
from app.core.points_limits import clamp_reward_points
from app.models import (
    Mission,
    MissionUsage,
    Technique,
    TechniqueExecution,
    User,
    UserWeeklyKitChoice,
    WeeklyKitItem,
    WeeklyTechniqueKit,
)
from app.services.mission_crud_service import _cleanup_kit_trailing_slots, upsert_academy_kit_missions
from app.utils.iso_week import iso_week_key_for_date, utc_datetime_bounds_for_iso_week

logger = logging.getLogger(__name__)


async def list_active_kits_for_academy(db: AsyncSession, academy_id: UUID) -> list[WeeklyTechniqueKit]:
    return (
        (
            await db.execute(
                select(WeeklyTechniqueKit)
                .where(
                    WeeklyTechniqueKit.academy_id == academy_id,
                    WeeklyTechniqueKit.deleted_at.is_(None),
                )
                .options(selectinload(WeeklyTechniqueKit.items).selectinload(WeeklyKitItem.technique))
                .order_by(WeeklyTechniqueKit.sort_order.asc(), WeeklyTechniqueKit.label.asc())
            )
        )
        .unique()
        .scalars()
        .all()
    )


async def academy_has_active_weekly_kits(db: AsyncSession, academy_id: UUID) -> bool:
    """True se existe pelo menos um kit não removido com 1–5 técnicas (modo kits ativo)."""
    kits = await list_active_kits_for_academy(db, academy_id)
    for k in kits:
        n = len(k.items or [])
        if 1 <= n <= 5:
            return True
    return False


async def get_kit(db: AsyncSession, kit_id: UUID, academy_id: UUID) -> WeeklyTechniqueKit | None:
    return (
        (
            await db.execute(
                select(WeeklyTechniqueKit)
                .where(
                    WeeklyTechniqueKit.id == kit_id,
                    WeeklyTechniqueKit.academy_id == academy_id,
                    WeeklyTechniqueKit.deleted_at.is_(None),
                )
                .options(selectinload(WeeklyTechniqueKit.items).selectinload(WeeklyKitItem.technique))
            )
        )
        .unique()
        .scalars()
        .first()
    )


async def create_kit(
    db: AsyncSession,
    academy_id: UUID,
    *,
    label: str,
    sort_order: int = 0,
) -> WeeklyTechniqueKit:
    kit = WeeklyTechniqueKit(
        academy_id=academy_id,
        label=label.strip(),
        sort_order=sort_order,
    )
    db.add(kit)
    await db.commit()
    await db.refresh(kit)
    logger.info("weekly_kit_created", extra={"kit_id": str(kit.id), "academy_id": str(academy_id)})
    return kit


async def update_kit_meta(
    db: AsyncSession,
    kit_id: UUID,
    academy_id: UUID,
    *,
    label: str | None = None,
    sort_order: int | None = None,
) -> WeeklyTechniqueKit | None:
    kit = await get_kit(db, kit_id, academy_id)
    if not kit:
        return None
    if label is not None:
        kit.label = label.strip()
    if sort_order is not None:
        kit.sort_order = sort_order
    kit.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(kit)
    return kit


async def soft_delete_kit(db: AsyncSession, kit_id: UUID, academy_id: UUID) -> bool:
    kit = (
        (
            await db.execute(
                select(WeeklyTechniqueKit).where(
                    WeeklyTechniqueKit.id == kit_id,
                    WeeklyTechniqueKit.academy_id == academy_id,
                    WeeklyTechniqueKit.deleted_at.is_(None),
                )
            )
        )
        .scalars()
        .first()
    )
    if not kit:
        return False
    now = datetime.now(timezone.utc)
    kit.deleted_at = now
    kit.updated_at = now
    await _cleanup_kit_trailing_slots(db, academy_id, kit_id, 0)
    await db.execute(sa_delete(WeeklyKitItem).where(WeeklyKitItem.kit_id == kit_id))
    await db.commit()
    logger.info("weekly_kit_soft_deleted", extra={"kit_id": str(kit_id)})
    return True


async def replace_kit_items_and_sync_missions(
    db: AsyncSession,
    kit_id: UUID,
    academy_id: UUID,
    items: list[tuple[UUID, int]],
) -> WeeklyTechniqueKit:
    """
    Substitui itens do kit (ordem = ordem da lista) e sincroniza missões.
    items: (technique_id, multiplier) — entre 1 e 5 entradas.
    """
    if len(items) < 1 or len(items) > 5:
        raise AppError("Cada kit deve ter entre 1 e 5 técnicas.", status_code=400)
    kit = await get_kit(db, kit_id, academy_id)
    if not kit:
        raise NotFoundError("Kit não encontrado.")
    for tid, mult in items:
        tech = (
            (
                await db.execute(
                    select(Technique).where(
                        Technique.id == tid,
                        Technique.deleted_at.is_(None),
                    )
                )
            )
            .scalars()
            .first()
        )
        if not tech:
            raise AppError("Técnica não encontrada.", status_code=400)
        if tech.academy_id is not None and tech.academy_id != academy_id:
            raise AppError("A técnica não pertence à academia deste kit.", status_code=400)
        clamp_reward_points(mult)

    await db.execute(sa_delete(WeeklyKitItem).where(WeeklyKitItem.kit_id == kit_id))
    for order_index, (tid, mult) in enumerate(items):
        db.add(
            WeeklyKitItem(
                kit_id=kit_id,
                order_index=order_index,
                technique_id=tid,
                multiplier=clamp_reward_points(mult),
            )
        )
    kit.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(kit)

    mission_items = [(tid, clamp_reward_points(m)) for tid, m in items]
    await upsert_academy_kit_missions(
        db,
        academy_id,
        kit_id,
        mission_items,
        date(2020, 1, 6),
        date(2099, 12, 31),
    )
    return (await get_kit(db, kit_id, academy_id)) or kit


async def get_user_kit_choice(
    db: AsyncSession,
    user_id: UUID,
    academy_id: UUID,
    iso_year: int,
    iso_week: int,
) -> UserWeeklyKitChoice | None:
    return (
        (
            await db.execute(
                select(UserWeeklyKitChoice).where(
                    UserWeeklyKitChoice.user_id == user_id,
                    UserWeeklyKitChoice.academy_id == academy_id,
                    UserWeeklyKitChoice.iso_week_year == iso_year,
                    UserWeeklyKitChoice.iso_week_number == iso_week,
                )
            )
        )
        .scalars()
        .first()
    )


async def has_user_kit_mission_activity_in_iso_week(
    db: AsyncSession,
    user_id: UUID,
    academy_id: UUID,
    iso_year: int,
    iso_week: int,
) -> bool:
    """True se o usuário concluiu (MissionUsage ou execução confirmada) alguma missão de kit nesta semana ISO."""
    start, end = utc_datetime_bounds_for_iso_week(iso_year, iso_week)
    mu = (
        (
            await db.execute(
                select(MissionUsage.id)
                .join(Mission, MissionUsage.mission_id == Mission.id)
                .where(
                    MissionUsage.user_id == user_id,
                    Mission.academy_id == academy_id,
                    Mission.weekly_kit_id.isnot(None),
                    MissionUsage.completed_at >= start,
                    MissionUsage.completed_at < end,
                )
                .limit(1)
            )
        )
        .first()
    )
    if mu:
        return True
    te = (
        (
            await db.execute(
                select(TechniqueExecution.id)
                .join(Mission, TechniqueExecution.mission_id == Mission.id)
                .where(
                    TechniqueExecution.user_id == user_id,
                    Mission.academy_id == academy_id,
                    Mission.weekly_kit_id.isnot(None),
                    TechniqueExecution.status == "confirmed",
                    TechniqueExecution.confirmed_at.isnot(None),
                    TechniqueExecution.confirmed_at >= start,
                    TechniqueExecution.confirmed_at < end,
                )
                .limit(1)
            )
        )
        .first()
    )
    return te is not None


async def set_user_weekly_kit_choice(
    db: AsyncSession,
    user_id: UUID,
    academy_id: UUID,
    kit_id: UUID,
    *,
    reference_date: date | None = None,
) -> UserWeeklyKitChoice:
    iso_year, iso_week = iso_week_key_for_date(reference_date)
    kit = await get_kit(db, kit_id, academy_id)
    if not kit:
        raise NotFoundError("Kit não encontrado ou não pertence à sua academia.")
    items_count = (
        await db.execute(
            select(func.count()).select_from(WeeklyKitItem).where(WeeklyKitItem.kit_id == kit_id)
        )
    ).scalar_one()
    ic = int(items_count or 0)
    if ic < 1 or ic > 5:
        raise AppError("Kit inválido: deve ter entre 1 e 5 técnicas cadastradas.", status_code=400)

    existing = await get_user_kit_choice(db, user_id, academy_id, iso_year, iso_week)
    if existing and existing.kit_id != kit_id:
        blocked = await has_user_kit_mission_activity_in_iso_week(
            db, user_id, academy_id, iso_year, iso_week
        )
        if blocked:
            raise AppError(
                "Não é possível trocar de kit: já há conclusão ou execução confirmada "
                "nesta semana em missões do kit anterior.",
                status_code=409,
            )
        existing.kit_id = kit_id
        existing.chosen_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(existing)
        return existing

    if existing:
        return existing

    row = UserWeeklyKitChoice(
        user_id=user_id,
        academy_id=academy_id,
        iso_week_year=iso_year,
        iso_week_number=iso_week,
        kit_id=kit_id,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def kit_missions_in_sync_with_items(
    db: AsyncSession,
    academy_id: UUID,
    kit_id: UUID,
    items: list[tuple[UUID, int]],
) -> bool:
    """
    True se já existem missões ativas (beginner + intermediate) por slot 0..n-1
    alinhadas a items (técnica + multiplicador), sem slots extra ativos para este kit.
    """
    if not items:
        return False
    n = len(items)
    missions = (
        (
            await db.execute(
                select(Mission).where(
                    Mission.academy_id == academy_id,
                    Mission.weekly_kit_id == kit_id,
                    Mission.deleted_at.is_(None),
                    Mission.is_active.is_(True),
                )
            )
        )
        .scalars()
        .all()
    )
    by_slot: dict[int, dict[str, Mission]] = {}
    for m in missions:
        si = m.slot_index
        if si is None:
            return False
        if si >= n:
            return False
        lvl = (m.level or "").lower().strip()
        if lvl not in ("beginner", "intermediate"):
            return False
        bucket = by_slot.setdefault(si, {})
        if lvl in bucket:
            return False
        bucket[lvl] = m
    if set(by_slot.keys()) != set(range(n)):
        return False
    for i in range(n):
        d = by_slot[i]
        if "beginner" not in d or "intermediate" not in d:
            return False
        tid, mult = items[i]
        mult_c = clamp_reward_points(mult)
        for lvl in ("beginner", "intermediate"):
            mm = d[lvl]
            if mm.technique_id != tid or mm.multiplier != mult_c:
                return False
    return True


async def assert_user_may_complete_kit_mission(
    db: AsyncSession,
    user_id: UUID,
    mission: Mission,
    *,
    reference_date: date | None = None,
) -> None:
    if mission.weekly_kit_id is None:
        return
    if mission.academy_id is None:
        return
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user and user.role == "administrador":
        return
    iso_year, iso_week = iso_week_key_for_date(reference_date)
    choice = await get_user_kit_choice(db, user_id, mission.academy_id, iso_year, iso_week)
    if choice is None or choice.kit_id != mission.weekly_kit_id:
        raise AppError(
            "Escolha o kit da semana (turma) correspondente ao seu treino antes de concluir esta missão.",
            status_code=403,
        )


async def ensure_kit_missions_from_db_items(
    db: AsyncSession,
    academy_id: UUID,
    kit_id: UUID,
) -> None:
    """Garante missões alinhadas aos weekly_kit_items (ex.: após deploy ou reparo).

    Se já estiverem sincronizadas (turma guardada pelo professor), evita o upsert
    pesado com vários commits — acelera o GET /mission_today/week após escolha do aluno.
    """
    kit = await get_kit(db, kit_id, academy_id)
    if not kit or not kit.items:
        return
    ordered = sorted(kit.items, key=lambda x: x.order_index)
    items = [(it.technique_id, it.multiplier) for it in ordered]
    if await kit_missions_in_sync_with_items(db, academy_id, kit_id, items):
        return
    await upsert_academy_kit_missions(
        db,
        academy_id,
        kit_id,
        items,
        date(2020, 1, 6),
        date(2099, 12, 31),
    )
