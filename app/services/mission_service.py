import logging
from datetime import date

from sqlalchemy.orm import Session, joinedload

from app.models import Lesson, Mission, Technique
from app.schemas.mission import MissionTodayResponse

logger = logging.getLogger(__name__)


def get_today_mission(db: Session, level: str = "beginner") -> Mission | None:
    """
    Retorna a missão ativa cuja data atual esteja entre start_date e end_date,
    para o nível indicado (beginner/intermediate), com a Lesson associada carregada.
    Se houver mais de uma, retorna a primeira (ordem por start_date).
    """
    today = date.today()
    level_normalized = (level or "beginner").lower().strip()
    if level_normalized not in ("beginner", "intermediate"):
        level_normalized = "beginner"
    mission = (
        db.query(Mission)
        .filter(
            Mission.is_active.is_(True),
            Mission.start_date <= today,
            Mission.end_date >= today,
            Mission.level == level_normalized,
        )
        .options(
            joinedload(Mission.lesson).joinedload(Lesson.technique).joinedload(Technique.from_position),
            joinedload(Mission.lesson).joinedload(Lesson.technique).joinedload(Technique.to_position),
        )
        .order_by(Mission.start_date.asc())
        .first()
    )
    if mission:
        logger.info(
            "get_today_mission",
            extra={"mission_id": str(mission.id), "lesson_id": str(mission.lesson_id), "level": level_normalized},
        )
    else:
        logger.info("get_today_mission", extra={"found": False, "level": level_normalized})
    return mission


def _lesson_to_mission_today_response(lesson: Lesson, mission_title: str = "Missão do dia") -> MissionTodayResponse:
    """Monta MissionTodayResponse a partir de Lesson (technique e posições já carregados). Sem queries extras."""
    technique = lesson.technique
    description = (lesson.content or technique.description) or ""
    position_name = f"{technique.from_position.name} → {technique.to_position.name}"
    return MissionTodayResponse(
        mission_title=mission_title,
        lesson_title=lesson.title,
        description=description,
        video_url=lesson.video_url or "",
        position_name=position_name,
        technique_name=technique.name,
        objective=lesson.content or technique.description or None,
        estimated_duration_seconds=None,
    )


def get_mission_today_response(db: Session, level: str = "beginner") -> MissionTodayResponse | None:
    """
    Retorna o payload da missão do dia pronto para o frontend (por nível).
    Usa get_today_mission(level); se não houver missão ativa para o nível, fallback
    na primeira lição. Sem queries adicionais.
    """
    mission = get_today_mission(db, level=level)
    if mission and mission.lesson:
        logger.info("get_mission_today_response", extra={"source": "mission", "lesson_id": str(mission.lesson_id)})
        return _lesson_to_mission_today_response(mission.lesson)
    # Fallback: primeira lição por order_index
    logger.warning("get_mission_today_response using_fallback", extra={"reason": "no_mission_today"})
    lesson = (
        db.query(Lesson)
        .options(
            joinedload(Lesson.technique).joinedload(Technique.from_position),
            joinedload(Lesson.technique).joinedload(Technique.to_position),
        )
        .order_by(Lesson.order_index.asc())
        .first()
    )
    if not lesson:
        logger.info("get_mission_today_response", extra={"found": False})
        return None
    logger.info("get_mission_today_response", extra={"source": "fallback", "lesson_id": str(lesson.id)})
    return _lesson_to_mission_today_response(lesson)


def get_mission_today(db: Session, level: str = "beginner") -> Lesson | None:
    """
    Retorna a lição do dia (compatibilidade).
    Usa get_today_mission(level); se existir missão ativa, retorna a Lesson associada.
    Caso contrário, fallback: primeira lição por order_index.
    """
    mission = get_today_mission(db, level=level)
    if mission and mission.lesson:
        return mission.lesson
    return (
        db.query(Lesson)
        .options(
            joinedload(Lesson.technique).joinedload(Technique.from_position),
            joinedload(Lesson.technique).joinedload(Technique.to_position),
        )
        .order_by(Lesson.order_index.asc())
        .first()
    )
