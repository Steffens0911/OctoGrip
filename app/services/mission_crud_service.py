"""CRUD de Mission para painel do professor (T-01). Missão = técnica + slot da academia (sem datas)."""
import logging
from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import select, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AcademyNotFoundError, AppError, LessonNotFoundError, TechniqueNotFoundError
from app.core.points_limits import MIN_REWARD_POINTS, clamp_reward_points
from app.models import Academy, Lesson, Mission, MissionUsage, Technique
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)

logger = logging.getLogger(__name__)

_ENTITY_MISSION = "Mission"


def _normalize_level_or_raise(level: str | None) -> str:
    level_n = (level or "beginner").lower().strip()
    if level_n not in ("beginner", "intermediate"):
        raise AppError(
            "Nível inválido. Use 'beginner' ou 'intermediate'.",
            status_code=400,
        )
    return level_n


def _validate_slot_index(slot_index: int | None) -> None:
    if slot_index is not None and slot_index not in (0, 1, 2):
        raise AppError("slot_index inválido. Use 0, 1 ou 2.", status_code=400)


def _validate_date_range(start_date: date | None, end_date: date | None) -> None:
    if start_date and end_date and end_date < start_date:
        raise AppError("end_date deve ser igual ou posterior a start_date.", status_code=400)


async def _validate_lesson_for_mission(
    db: AsyncSession,
    *,
    lesson_id: UUID,
    technique_id: UUID,
    academy_id: UUID | None,
) -> None:
    lesson = (
        await db.execute(
            select(Lesson).where(
                Lesson.id == lesson_id,
                Lesson.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if not lesson:
        raise LessonNotFoundError("Lição não encontrada para vincular à missão.")
    if lesson.technique_id != technique_id:
        raise AppError(
            "A lição informada não pertence à técnica da missão.",
            status_code=400,
        )
    if academy_id is not None and lesson.academy_id not in (None, academy_id):
        raise AppError(
            "A lição informada não pertence à academia da missão.",
            status_code=400,
        )


async def _first_lesson_id_for_technique(db: AsyncSession, technique_id: UUID) -> UUID | None:
    """Retorna o id da primeira lição da técnica (por order_index)."""
    first = (
        await db.execute(
            select(Lesson)
            .where(
                Lesson.technique_id == technique_id,
                Lesson.deleted_at.is_(None),
            )
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
    audit_user_id: UUID | None = None,
) -> Mission:
    """Cria uma missão (técnica + slot da academia). Se lesson_id não for informado, usa a primeira lição da técnica."""
    _validate_slot_index(slot_index)
    _validate_date_range(start_date, end_date)
    technique = (
        await db.execute(
            select(Technique).where(
                Technique.id == technique_id,
                Technique.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if not technique:
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if academy_id is not None:
        academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
        if not academy:
            raise AcademyNotFoundError()
        if technique.academy_id is not None and technique.academy_id != academy_id:
            raise AppError(
                "A técnica informada não pertence à academia da missão.",
                status_code=400,
            )
    level_n = _normalize_level_or_raise(level)
    if lesson_id is None:
        lesson_id = await _first_lesson_id_for_technique(db, technique_id)
    else:
        await _validate_lesson_for_mission(
            db,
            lesson_id=lesson_id,
            technique_id=technique_id,
            academy_id=academy_id,
        )
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
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_MISSION,
        entity_id=mission.id,
        old_data=None,
        new_data=entity_snapshot_row(mission),
        user_id=audit_user_id,
    )
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


async def get_mission(
    db: AsyncSession, mission_id: UUID, *, include_deleted: bool = False
) -> Mission | None:
    """Retorna uma missão por ID. Por padrão ignora soft-deletadas."""
    stmt = select(Mission).where(Mission.id == mission_id)
    if not include_deleted:
        stmt = stmt.where(Mission.deleted_at.is_(None))
    return (await db.execute(stmt)).scalar_one_or_none()


async def list_missions(
    db: AsyncSession,
    academy_id: UUID | None = None,
    limit: int = 100,
    *,
    include_deleted: bool = False,
) -> list[Mission]:
    """Lista missões, opcionalmente filtradas por academia (eager load technique para technique_name)."""
    stmt = (
        select(Mission)
        .options(selectinload(Mission.technique))
        .order_by(Mission.slot_index.asc().nullslast(), Mission.id.desc())
        .limit(limit)
    )
    if not include_deleted:
        stmt = stmt.where(Mission.deleted_at.is_(None))
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
    audit_user_id: UUID | None = None,
) -> Mission | None:
    """Atualiza uma missão (campos opcionais). Use _set_academy_id_none=True para limpar academia."""
    mission = (await db.execute(select(Mission).where(Mission.id == mission_id))).scalar_one_or_none()
    if not mission or mission.deleted_at is not None:
        return None
    _validate_slot_index(slot_index)
    effective_start = start_date if start_date is not None else mission.start_date
    effective_end = end_date if end_date is not None else mission.end_date
    _validate_date_range(effective_start, effective_end)

    before = entity_snapshot_row(mission)
    next_technique_id = technique_id if technique_id is not None else mission.technique_id
    next_academy_id = mission.academy_id
    if _set_academy_id_none:
        next_academy_id = None
    elif academy_id is not None:
        next_academy_id = academy_id

    if technique_id is not None and technique_id != mission.technique_id:
        technique = (
            await db.execute(
                select(Technique).where(
                    Technique.id == technique_id,
                    Technique.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if not technique:
            raise TechniqueNotFoundError("Técnica não encontrada.")
        if next_academy_id is not None and technique.academy_id not in (None, next_academy_id):
            raise AppError(
                "A técnica informada não pertence à academia da missão.",
                status_code=400,
            )
        result = await db.execute(sa_delete(MissionUsage).where(MissionUsage.mission_id == mission_id))
        deleted = result.rowcount
        if deleted:
            logger.info("update_mission cleared_usage", extra={"mission_id": str(mission_id), "deleted": deleted})
        mission.technique_id = technique_id
        if lesson_id is None:
            mission.lesson_id = await _first_lesson_id_for_technique(db, technique_id)
    if lesson_id is not None:
        await _validate_lesson_for_mission(
            db,
            lesson_id=lesson_id,
            technique_id=next_technique_id,
            academy_id=next_academy_id,
        )
        mission.lesson_id = lesson_id
    if start_date is not None:
        mission.start_date = start_date
    if end_date is not None:
        mission.end_date = end_date
    if slot_index is not None:
        mission.slot_index = slot_index
    if level is not None:
        mission.level = _normalize_level_or_raise(level)
    if theme is not None:
        mission.theme = theme
    if _set_academy_id_none:
        mission.academy_id = None
    elif academy_id is not None:
        academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
        if not academy:
            raise AcademyNotFoundError()
        current_technique = (
            await db.execute(
                select(Technique).where(
                    Technique.id == mission.technique_id,
                    Technique.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if current_technique and current_technique.academy_id not in (None, academy_id):
            raise AppError(
                "A técnica atual da missão não pertence à academia informada.",
                status_code=400,
            )
        mission.academy_id = academy_id
    if is_active is not None:
        mission.is_active = is_active
    if multiplier is not None:
        mission.multiplier = clamp_reward_points(multiplier)
    after = entity_snapshot_row(mission)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_MISSION,
            entity_id=mission.id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(mission)
    logger.info("update_mission", extra={"mission_id": str(mission_id)})
    return mission


async def delete_mission(
    db: AsyncSession, mission_id: UUID, audit_user_id: UUID | None = None
) -> bool:
    """Soft delete de uma missão. Retorna True se marcou como removida."""
    mission = (await db.execute(select(Mission).where(Mission.id == mission_id))).scalar_one_or_none()
    if not mission or mission.deleted_at is not None:
        return False
    before = entity_snapshot_row(mission)
    now = datetime.now(timezone.utc)
    mission.deleted_at = now
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_MISSION,
        entity_id=mission.id,
        old_data=before,
        new_data={"deleted_at": now.isoformat()},
        user_id=audit_user_id,
    )
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
    technique = (
        await db.execute(
            select(Technique).where(
                Technique.id == tech_id,
                Technique.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
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
                        Mission.deleted_at.is_(None),
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
                                Mission.deleted_at.is_(None),
                            )
                        )
                    ).scalar_one_or_none()
                    if old:
                        before = entity_snapshot_row(old)
                        old.deleted_at = datetime.now(timezone.utc)
                        await write_audit_log(
                            db,
                            action=AUDIT_ACTION_DELETE,
                            entity_label=_ENTITY_MISSION,
                            entity_id=old.id,
                            old_data=before,
                            new_data={"deleted_at": old.deleted_at.isoformat()},
                            user_id=None,
                        )
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
                                Mission.deleted_at.is_(None),
                            )
                        )
                    ).scalar_one_or_none()
                    if old:
                        before = entity_snapshot_row(old)
                        old.deleted_at = datetime.now(timezone.utc)
                        await write_audit_log(
                            db,
                            action=AUDIT_ACTION_DELETE,
                            entity_label=_ENTITY_MISSION,
                            entity_id=old.id,
                            old_data=before,
                            new_data={"deleted_at": old.deleted_at.isoformat()},
                            user_id=None,
                        )
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
