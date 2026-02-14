"""CRUD de Mission para painel do professor (T-01). Missão = técnica + período."""
import logging
from datetime import date, timedelta
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.exceptions import AcademyNotFoundError, TechniqueNotFoundError
from app.models import Academy, Mission, MissionUsage, Technique

logger = logging.getLogger(__name__)


def create_mission(
    db: Session,
    technique_id: UUID,
    start_date: date,
    end_date: date,
    level: str = "beginner",
    theme: str | None = None,
    academy_id: UUID | None = None,
) -> Mission:
    """T-01: Cria uma missão (técnica + período). Valida technique e opcionalmente academy."""
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
    mission = Mission(
        technique_id=technique_id,
        start_date=start_date,
        end_date=end_date,
        is_active=True,
        level=level_n,
        theme=theme,
        academy_id=academy_id,
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
    """Lista missões, opcionalmente filtradas por academia."""
    q = db.query(Mission).order_by(Mission.start_date.desc()).limit(limit)
    if academy_id is not None:
        q = q.filter(Mission.academy_id == academy_id)
    return q.all()


def update_mission(
    db: Session,
    mission_id: UUID,
    *,
    technique_id: UUID | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
    level: str | None = None,
    theme: str | None = None,
    academy_id: UUID | None = None,
    is_active: bool | None = None,
    _set_academy_id_none: bool = False,
) -> Mission | None:
    """Atualiza uma missão (campos opcionais). Use _set_academy_id_none=True para limpar academia."""
    mission = db.query(Mission).filter(Mission.id == mission_id).first()
    if not mission:
        return None
    if technique_id is not None and technique_id != mission.technique_id:
        technique = db.query(Technique).filter(Technique.id == technique_id).first()
        if not technique:
            return None
        deleted = db.query(MissionUsage).filter(MissionUsage.mission_id == mission_id).delete()
        if deleted:
            logger.info("update_mission cleared_usage", extra={"mission_id": str(mission_id), "deleted": deleted})
        mission.technique_id = technique_id
    if start_date is not None:
        mission.start_date = start_date
    if end_date is not None:
        mission.end_date = end_date
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
    week_start: date,
    week_end: date,
) -> list[Mission]:
    """
    Cria ou atualiza as missões da academia para a semana.
    technique_ids = (slot1, slot2, slot3): seg-ter, qua-qui, sex-dom.
    Se só slot1 preenchido: uma missão por nível para a semana inteira (comportamento legado).
    Se 2 ou 3 preenchidos: uma missão por nível por slot, com intervalos seg-ter, qua-qui, sex-dom.
    """
    t1, t2, t3 = technique_ids
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        raise AcademyNotFoundError()

    result: list[Mission] = []
    use_three_slots = t2 is not None or t3 is not None

    if use_three_slots:
        # Slots: seg-ter (0-1), qua-qui (2-3), sex-dom (4-6)
        slots: list[tuple[date, date, UUID | None]] = [
            (week_start, week_start + timedelta(days=1), t1),
            (week_start + timedelta(days=2), week_start + timedelta(days=3), t2),
            (week_start + timedelta(days=4), week_end, t3),
        ]
        # Remover missões da academia que cobrem a semana inteira (legado)
        for level in ("beginner", "intermediate"):
            full_week = (
                db.query(Mission)
                .filter(
                    Mission.academy_id == academy_id,
                    Mission.level == level,
                    Mission.start_date == week_start,
                    Mission.end_date == week_end,
                )
                .first()
            )
            if full_week:
                db.delete(full_week)
                db.commit()
                logger.info(
                    "upsert_academy_week_missions removed_full_week",
                    extra={"academy_id": str(academy_id), "level": level},
                )
        for slot_start, slot_end, tech_id in slots:
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
                        Mission.start_date == slot_start,
                    )
                    .first()
                )
                if existing:
                    if existing.technique_id != tech_id:
                        deleted = db.query(MissionUsage).filter(MissionUsage.mission_id == existing.id).delete()
                        if deleted:
                            logger.info(
                                "upsert_academy_week_missions cleared_usage",
                                extra={"mission_id": str(existing.id), "deleted": deleted},
                            )
                    existing.technique_id = tech_id
                    existing.end_date = slot_end
                    db.commit()
                    db.refresh(existing)
                    result.append(existing)
                else:
                    mission = create_mission(
                        db,
                        technique_id=tech_id,
                        start_date=slot_start,
                        end_date=slot_end,
                        level=level,
                        academy_id=academy_id,
                        theme=technique.name,
                    )
                    result.append(mission)
    else:
        # Apenas técnica 1: uma missão por nível para a semana inteira (legado)
        if t1 is None:
            return result
        # Remover missões de slot (seg-ter, qua-qui, sex-dom) se existirem
        slot_missions = (
            db.query(Mission)
            .filter(
                Mission.academy_id == academy_id,
                Mission.start_date >= week_start,
                Mission.end_date <= week_end,
            )
            .all()
        )
        for m in slot_missions:
            if (m.end_date - m.start_date).days < 6:
                db.delete(m)
        db.commit()
        technique = db.query(Technique).filter(Technique.id == t1).first()
        if not technique:
            raise TechniqueNotFoundError("Técnica não encontrada.")
        for level in ("beginner", "intermediate"):
            existing = (
                db.query(Mission)
                .filter(
                    Mission.academy_id == academy_id,
                    Mission.level == level,
                    Mission.start_date <= week_end,
                    Mission.end_date >= week_start,
                )
                .first()
            )
            if existing:
                if existing.technique_id != t1:
                    deleted = db.query(MissionUsage).filter(MissionUsage.mission_id == existing.id).delete()
                    if deleted:
                        logger.info(
                            "upsert_academy_week_missions cleared_usage",
                            extra={"mission_id": str(existing.id), "deleted": deleted},
                        )
                existing.technique_id = t1
                existing.start_date = week_start
                existing.end_date = week_end
                db.commit()
                db.refresh(existing)
                result.append(existing)
            else:
                mission = create_mission(
                    db,
                    technique_id=t1,
                    start_date=week_start,
                    end_date=week_end,
                    level=level,
                    academy_id=academy_id,
                    theme=technique.name,
                )
                result.append(mission)
    return result
