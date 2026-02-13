"""CRUD de Mission para painel do professor (T-01)."""
import logging
from datetime import date
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.exceptions import AcademyNotFoundError, LessonNotFoundError
from app.models import Academy, Lesson, Mission

logger = logging.getLogger(__name__)


def create_mission(
    db: Session,
    lesson_id: UUID,
    start_date: date,
    end_date: date,
    level: str = "beginner",
    theme: str | None = None,
    academy_id: UUID | None = None,
) -> Mission:
    """T-01: Cria uma missão (professor). Valida lesson e opcionalmente academy."""
    lesson = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not lesson:
        raise LessonNotFoundError("Lição não encontrada.")
    if academy_id is not None:
        academy = db.query(Academy).filter(Academy.id == academy_id).first()
        if not academy:
            raise AcademyNotFoundError()
    level_n = (level or "beginner").lower().strip()
    if level_n not in ("beginner", "intermediate"):
        level_n = "beginner"
    mission = Mission(
        lesson_id=lesson_id,
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
        extra={"mission_id": str(mission.id), "lesson_id": str(lesson_id), "academy_id": str(academy_id) if academy_id else None},
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
    lesson_id: UUID | None = None,
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
    if lesson_id is not None:
        lesson = db.query(Lesson).filter(Lesson.id == lesson_id).first()
        if not lesson:
            return None
        mission.lesson_id = lesson_id
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
