"""CRUD de Mission para painel do professor (T-01). Missão = técnica + slot da academia (sem datas)."""
import logging
from datetime import date
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import AcademyNotFoundError, TechniqueNotFoundError
from app.models import Academy, Lesson, Mission, MissionUsage, Technique

logger = logging.getLogger(__name__)


def _first_lesson_id_for_technique(db: Session, technique_id: UUID) -> UUID | None:
    """Retorna o id da primeira lição da técnica (por order_index)."""
    first = (
        db.query(Lesson)
        .filter(Lesson.technique_id == technique_id)
        .order_by(Lesson.order_index.asc())
        .first()
    )
    return first.id if first else None


def create_mission(
    db: Session,
    technique_id: UUID,
    level: str = "beginner",
    theme: str | None = None,
    academy_id: UUID | None = None,
    lesson_id: UUID | None = None,
    multiplier: int = 1,
    *,
    slot_index: int | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
) -> Mission:
    """Cria uma missão (técnica + slot da academia). Se lesson_id não for informado, usa a primeira lição da técnica."""
    technique = db.query(Technique).filter(Technique.id == technique_id).first()
    if not technique:
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if academy_id is not None:
        academy = db.query(Academy).filter(Academy.id == academy_id).first()
        if not academy:
            raise AcademyNotFoundError()
    level_n = (level or "beginner").lower().strip()
    if level_n not in ("beginner", "intermediate"):
        level_n = "beginner"
    if lesson_id is None:
        lesson_id = _first_lesson_id_for_technique(db, technique_id)
    mult = max(1, multiplier) if multiplier is not None else 1
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
    db.commit()
    db.refresh(mission)
    logger.info(
        "create_mission",
        extra={
            "mission_id": str(mission.id),
            "technique_id": str(technique_id),
            "academy_id": str(academy_id) if academy_id else None,
        },
    )
    return mission


def get_mission(db: Session, mission_id: UUID) -> Mission | None:
    """Retorna uma missão por ID."""
    return db.query(Mission).filter(Mission.id == mission_id).first()


def list_missions(
    db: Session,
    academy_id: UUID | None = None,
    limit: int = 100,
) -> list[Mission]:
    """Lista missões, opcionalmente filtradas por academia (eager load technique para technique_name)."""
    q = (
        db.query(Mission)
        .options(joinedload(Mission.technique))
        .order_by(Mission.slot_index.asc().nullslast(), Mission.id.desc())
        .limit(limit)
    )
    if academy_id is not None:
        q = q.filter(Mission.academy_id == academy_id)
    return q.all()


def update_mission(
    db: Session,
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
    mission = db.query(Mission).filter(Mission.id == mission_id).first()
    if not mission:
        return None
    if lesson_id is not None:
        mission.lesson_id = lesson_id
    if technique_id is not None and technique_id != mission.technique_id:
        technique = db.query(Technique).filter(Technique.id == technique_id).first()
        if not technique:
            return None
        deleted = db.query(MissionUsage).filter(MissionUsage.mission_id == mission_id).delete()
        if deleted:
            logger.info("update_mission cleared_usage", extra={"mission_id": str(mission_id), "deleted": deleted})
        mission.technique_id = technique_id
        if lesson_id is None:
            mission.lesson_id = _first_lesson_id_for_technique(db, technique_id)
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
    if multiplier is not None and multiplier >= 1:
        mission.multiplier = multiplier
    db.commit()
    db.refresh(mission)
    logger.info("update_mission", extra={"mission_id": str(mission_id)})
    return mission


def delete_mission(db: Session, mission_id: UUID) -> bool:
    """Remove uma missão. Retorna True se removeu."""
    mission = db.query(Mission).filter(Mission.id == mission_id).first()
    if not mission:
        return False
    db.delete(mission)
    db.commit()
    logger.info("delete_mission", extra={"mission_id": str(mission_id)})
    return True


def upsert_academy_week_missions(
    db: Session,
    academy_id: UUID,
    technique_ids: tuple[UUID | None, UUID | None, UUID | None],
    week_start: date | None = None,
    week_end: date | None = None,
) -> list[Mission]:
    """
    Cria ou atualiza as 3 missões da academia por slot_index (0, 1, 2).
    Sem datas: cada academia define suas missões pelos 3 slots.
    """
    t1, t2, t3 = technique_ids
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise AcademyNotFoundError()

    result: list[Mission] = []
    m1 = getattr(academy, "weekly_multiplier_1", 1) or 1
    m2 = getattr(academy, "weekly_multiplier_2", 1) or 1
    m3 = getattr(academy, "weekly_multiplier_3", 1) or 1

    tech_slots = [(t1, m1), (t2, m2), (t3, m3)]
    for slot_idx, (tech_id, mult) in enumerate(tech_slots):
        if tech_id is None:
            continue
        technique = db.query(Technique).filter(Technique.id == tech_id).first()
        if not technique:
            raise TechniqueNotFoundError("Técnica não encontrada.")
        for level in ("beginner", "intermediate"):
            existing = (
                db.query(Mission)
                .filter(
                    Mission.academy_id == academy_id,
                    Mission.level == level,
                    Mission.slot_index == slot_idx,
                )
                .first()
            )
            if existing:
                if existing.technique_id != tech_id:
                    existing.is_active = False
                    db.commit()
                    mission = create_mission(
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
                    existing.multiplier = mult
                    db.commit()
                    db.refresh(existing)
                    result.append(existing)
            else:
                mission = create_mission(
                    db,
                    technique_id=tech_id,
                    level=level,
                    academy_id=academy_id,
                    theme=technique.name,
                    multiplier=mult,
                    slot_index=slot_idx,
                )
                result.append(mission)

    if t1 is None and t2 is None and t3 is None:
        for level in ("beginner", "intermediate"):
            for slot_idx in (0, 1, 2):
                old = (
                    db.query(Mission)
                    .filter(
                        Mission.academy_id == academy_id,
                        Mission.level == level,
                        Mission.slot_index == slot_idx,
                    )
                    .first()
                )
                if old:
                    db.delete(old)
                    db.commit()
    else:
        for slot_idx, (tech_id, _) in enumerate(tech_slots):
            if tech_id is not None:
                continue
            for level in ("beginner", "intermediate"):
                old = (
                    db.query(Mission)
                    .filter(
                        Mission.academy_id == academy_id,
                        Mission.level == level,
                        Mission.slot_index == slot_idx,
                    )
                    .first()
                )
                if old:
                    db.delete(old)
                    db.commit()
    return result
