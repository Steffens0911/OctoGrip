"""CRUD de Mission para painel do professor (T-01). Missão = técnica + slot da academia (sem datas)."""
import logging
from datetime import date
from uuid import UUID

from sqlalchemy import select, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AcademyNotFoundError, TechniqueNotFoundError
from app.core.points_limits import MIN_REWARD_POINTS, clamp_reward_points
from app.models import Academy, Lesson, Mission, MissionUsage, Technique

logger = logging.getLogger(__name__)


async def _first_lesson_id_for_technique(db: AsyncSession, technique_id: UUID) -> UUID | None:
    """Retorna o id da primeira lição da técnica (por order_index)."""
    first = (
        await db.execute(
            select(Lesson)
            .where(Lesson.technique_id == technique_id)
            .order_by(Lesson.order_index.asc())
        )
    ).scalars().first()
    return first.id if first else None


async def create_mission(
    db: AsyncSession,
    technique_id: UUID,
    level: str = "beginner",
    theme: str | None = None,
    academy_id: UUID | None = None,
    lesson_id: UUID | None = None,
    multiplier: int = MIN_REWARD_POINTS,
    *,
    slot_index: int | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
) -> Mission:
    """Cria uma missão (técnica + slot da academia). Se lesson_id não for informado, usa a primeira lição da técnica."""
    technique = (await db.execute(select(Technique).where(Technique.id == technique_id))).scalar_one_or_none()
    if not technique:
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if academy_id is not None:
        academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
        if not academy:
            raise AcademyNotFoundError()
    level_n = (level or "beginner").lower().strip()
    if level_n not in ("beginner", "intermediate"):
        level_n = "beginner"
    if lesson_id is None:
        lesson_id = await _first_lesson_id_for_technique(db, technique_id)
    mult = clamp_reward_points(multiplier) if multiplier is not None else MIN_REWARD_POINTS
    mission = Mission(
        technique_id=technique_id,
        lesson_id=lesson_id,
        slot_index=slot_index,
        start_date=start_date,
        end_date=end_date,
        is_active=True,
        level=level_n,
        theme=theme,
        academy_id=academy_id,
        multiplier=mult,
    )
    db.add(mission)
    await db.commit()
    await db.refresh(mission)
    logger.info(
        "create_mission",
        extra={
            "mission_id": str(mission.id),
            "technique_id": str(technique_id),
            "academy_id": str(academy_id) if academy_id else None,
        },
    )
    return mission


async def get_mission(db: AsyncSession, mission_id: UUID) -> Mission | None:
    """Retorna uma missão por ID."""
    return (await db.execute(select(Mission).where(Mission.id == mission_id))).scalar_one_or_none()


async def list_missions(
    db: AsyncSession,
    academy_id: UUID | None = None,
    limit: int = 100,
) -> list[Mission]:
    """Lista missões, opcionalmente filtradas por academia (eager load technique para technique_name)."""
    stmt = (
        select(Mission)
        .options(selectinload(Mission.technique))
        .order_by(Mission.slot_index.asc().nullslast(), Mission.id.desc())
        .limit(limit)
    )
    if academy_id is not None:
        stmt = stmt.where(Mission.academy_id == academy_id)
    return (await db.execute(stmt)).unique().scalars().all()


async def update_mission(
    db: AsyncSession,
    mission_id: UUID,
    *,
    technique_id: UUID | None = None,
    lesson_id: UUID | None = None,
    slot_index: int | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
    level: str | None = None,
    theme: str | None = None,
    academy_id: UUID | None = None,
    is_active: bool | None = None,
    multiplier: int | None = None,
    _set_academy_id_none: bool = False,
) -> Mission | None:
    """Atualiza uma missão (campos opcionais). Use _set_academy_id_none=True para limpar academia."""
    mission = (await db.execute(select(Mission).where(Mission.id == mission_id))).scalar_one_or_none()
    if not mission:
        return None
    if lesson_id is not None:
        mission.lesson_id = lesson_id
    if technique_id is not None and technique_id != mission.technique_id:
        technique = (await db.execute(select(Technique).where(Technique.id == technique_id))).scalar_one_or_none()
        if not technique:
            return None
        result = await db.execute(sa_delete(MissionUsage).where(MissionUsage.mission_id == mission_id))
        deleted = result.rowcount
        if deleted:
            logger.info("update_mission cleared_usage", extra={"mission_id": str(mission_id), "deleted": deleted})
        mission.technique_id = technique_id
        if lesson_id is None:
            mission.lesson_id = await _first_lesson_id_for_technique(db, technique_id)
    if start_date is not None:
        mission.start_date = start_date
    if end_date is not None:
        mission.end_date = end_date
    if slot_index is not None:
        mission.slot_index = slot_index
    if level is not None:
        mission.level = level if level.lower() in ("beginner", "intermediate") else "beginner"
    if theme is not None:
        mission.theme = theme
    if _set_academy_id_none:
        mission.academy_id = None
    elif academy_id is not None:
        mission.academy_id = academy_id
    if is_active is not None:
        mission.is_active = is_active
    if multiplier is not None:
        mission.multiplier = clamp_reward_points(multiplier)
    await db.commit()
    await db.refresh(mission)
    logger.info("update_mission", extra={"mission_id": str(mission_id)})
    return mission


async def delete_mission(db: AsyncSession, mission_id: UUID) -> bool:
    """Remove uma missão. Retorna True se removeu."""
    mission = (await db.execute(select(Mission).where(Mission.id == mission_id))).scalar_one_or_none()
    if not mission:
        return False
    await db.delete(mission)
    await db.commit()
    logger.info("delete_mission", extra={"mission_id": str(mission_id)})
    return True


async def _upsert_slot_missions(
    db: AsyncSession,
    academy_id: UUID,
    slot_idx: int,
    tech_id: UUID,
    mult: int,
) -> list[Mission]:
    """
    Cria ou atualiza missões para um slot específico (beginner e intermediate).
    Retorna lista de missões criadas/atualizadas.
    """
    technique = (await db.execute(select(Technique).where(Technique.id == tech_id))).scalar_one_or_none()
    if not technique:
        raise TechniqueNotFoundError("Técnica não encontrada.")
    
    result: list[Mission] = []
    try:
        for level in ("beginner", "intermediate"):
            existing = (
                await db.execute(
                    select(Mission).where(
                        Mission.academy_id == academy_id,
                        Mission.level == level,
                        Mission.slot_index == slot_idx,
                    )
                )
            ).scalar_one_or_none()
            
            if existing:
                if existing.technique_id != tech_id:
                    # Técnica mudou: desativar antiga e criar nova
                    existing.is_active = False
                    await db.commit()
                    mission = await create_mission(
                        db,
                        technique_id=tech_id,
                        level=level,
                        academy_id=academy_id,
                        theme=technique.name,
                        multiplier=mult,
                        slot_index=slot_idx,
                    )
                    result.append(mission)
                    logger.info(
                        "upsert_academy_week_missions new_mission_after_technique_change",
                        extra={"old_mission_id": str(existing.id), "new_mission_id": str(mission.id)},
                    )
                else:
                    # Mesma técnica: apenas atualizar multiplicador
                    existing.multiplier = mult
                    await db.commit()
                    await db.refresh(existing)
                    result.append(existing)
            else:
                # Criar nova missão
                mission = await create_mission(
                    db,
                    technique_id=tech_id,
                    level=level,
                    academy_id=academy_id,
                    theme=technique.name,
                    multiplier=mult,
                    slot_index=slot_idx,
                )
                result.append(mission)
    except Exception:
        await db.rollback()
        raise
    
    return result


async def _cleanup_empty_slots(
    db: AsyncSession,
    academy_id: UUID,
    tech_slots: list[tuple[UUID | None, int]],
) -> None:
    """
    Remove missões de slots vazios (onde tech_id é None).
    Se todos os slots estão vazios, remove todas as missões.
    """
    t1, t2, t3 = tech_slots[0][0], tech_slots[1][0], tech_slots[2][0]
    
    try:
        if t1 is None and t2 is None and t3 is None:
            # Todos os slots vazios: remover todas as missões
            for level in ("beginner", "intermediate"):
                for slot_idx in (0, 1, 2):
                    old = (
                        await db.execute(
                            select(Mission).where(
                                Mission.academy_id == academy_id,
                                Mission.level == level,
                                Mission.slot_index == slot_idx,
                            )
                        )
                    ).scalar_one_or_none()
                    if old:
                        await db.delete(old)
                        await db.commit()
        else:
            # Remover apenas slots específicos vazios
            for slot_idx, (tech_id, _) in enumerate(tech_slots):
                if tech_id is not None:
                    continue
                for level in ("beginner", "intermediate"):
                    old = (
                        await db.execute(
                            select(Mission).where(
                                Mission.academy_id == academy_id,
                                Mission.level == level,
                                Mission.slot_index == slot_idx,
                            )
                        )
                    ).scalar_one_or_none()
                    if old:
                        await db.delete(old)
                        await db.commit()
    except Exception:
        await db.rollback()
        raise


async def upsert_academy_week_missions(
    db: AsyncSession,
    academy_id: UUID,
    technique_ids: tuple[UUID | None, UUID | None, UUID | None],
    week_start: date | None = None,
    week_end: date | None = None,
) -> list[Mission]:
    """
    Cria ou atualiza as 3 missões da academia por slot_index (0, 1, 2).
    Sem datas: cada academia define suas missões pelos 3 slots.
    """
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        raise AcademyNotFoundError()

    t1, t2, t3 = technique_ids
    m1 = clamp_reward_points(getattr(academy, "weekly_multiplier_1", MIN_REWARD_POINTS) or MIN_REWARD_POINTS)
    m2 = clamp_reward_points(getattr(academy, "weekly_multiplier_2", MIN_REWARD_POINTS) or MIN_REWARD_POINTS)
    m3 = clamp_reward_points(getattr(academy, "weekly_multiplier_3", MIN_REWARD_POINTS) or MIN_REWARD_POINTS)

    tech_slots = [(t1, m1), (t2, m2), (t3, m3)]
    result: list[Mission] = []
    
    try:
        # Criar/atualizar missões para slots preenchidos
        for slot_idx, (tech_id, mult) in enumerate(tech_slots):
            if tech_id is None:
                continue
            slot_missions = await _upsert_slot_missions(db, academy_id, slot_idx, tech_id, mult)
            result.extend(slot_missions)
        
        # Limpar slots vazios
        await _cleanup_empty_slots(db, academy_id, tech_slots)
        
    except Exception:
        await db.rollback()
        raise
    
    return result
