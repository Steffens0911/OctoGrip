import logging
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.models import Academy, Lesson, LessonProgress, Mission, Technique, TrainingFeedback, User
from app.schemas.mission import MissionTodayResponse

logger = logging.getLogger(__name__)


def get_today_mission(
    db: Session,
    level: str = "beginner",
    academy_id: UUID | None = None,
) -> Mission | None:
    """
    Retorna a missão ativa para o nível (e opcionalmente academia).
    A-02: Se academy_id for informado, busca primeiro missão da academia; se não houver, usa global (academy_id IS NULL).
    Se academy_id for None, busca apenas missões globais.
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
        joinedload(Mission.lesson).joinedload(Lesson.technique).joinedload(Technique.from_position),
        joinedload(Mission.lesson).joinedload(Lesson.technique).joinedload(Technique.to_position),
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
                "lesson_id": str(mission.lesson_id),
                "level": level_normalized,
                "academy_id": str(academy_id) if academy_id else None,
            },
        )
    else:
        logger.info("get_today_mission", extra={"found": False, "level": level_normalized})
    return mission


def _lesson_to_mission_today_response(
    lesson: Lesson,
    mission_title: str = "Missão do dia",
    weekly_theme: str | None = None,
    is_review: bool = False,
) -> MissionTodayResponse:
    """Monta MissionTodayResponse a partir de Lesson (technique e posições já carregados). Sem queries extras."""
    technique = lesson.technique
    description = (lesson.content or technique.description) or ""
    position_name = f"{technique.from_position.name} → {technique.to_position.name}"
    return MissionTodayResponse(
        lesson_id=lesson.id,
        mission_title=mission_title,
        lesson_title=lesson.title,
        description=description,
        video_url=lesson.video_url or "",
        position_name=position_name,
        technique_name=technique.name,
        objective=lesson.content or technique.description or None,
        estimated_duration_seconds=None,
        weekly_theme=weekly_theme,
        is_review=is_review,
    )


def _get_review_lesson(
    db: Session, user_id: UUID, review_after_days: int
) -> Lesson | None:
    """
    PF-03: Retorna uma lição que o usuário concluiu há pelo menos review_after_days dias
    (a mais antiga concluída, para priorizar revisão). None se não houver.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=review_after_days)
    row = (
        db.query(LessonProgress.lesson_id)
        .filter(
            LessonProgress.user_id == user_id,
            LessonProgress.completed_at <= cutoff,
        )
        .order_by(LessonProgress.completed_at.asc())
        .first()
    )
    if not row:
        return None
    lesson_id = row[0]
    lesson = (
        db.query(Lesson)
        .filter(Lesson.id == lesson_id)
        .options(
            joinedload(Lesson.technique).joinedload(Technique.from_position),
            joinedload(Lesson.technique).joinedload(Technique.to_position),
        )
        .first()
    )
    return lesson


def _get_difficult_position_lesson(
    db: Session, user_id: UUID, exclude_lesson_id: UUID | None = None
) -> Lesson | None:
    """
    PF-04: Retorna uma lição cuja técnica envolve alguma posição que o usuário
    marcou como difícil (training_feedback). Exclui exclude_lesson_id se informado.
    """
    position_ids = [
        row[0]
        for row in db.query(TrainingFeedback.position_id)
        .filter(TrainingFeedback.user_id == user_id)
        .distinct()
        .all()
    ]
    if not position_ids:
        return None
    q = (
        db.query(Lesson)
        .join(Technique, Lesson.technique_id == Technique.id)
        .filter(
            or_(
                Technique.from_position_id.in_(position_ids),
                Technique.to_position_id.in_(position_ids),
            )
        )
        .options(
            joinedload(Lesson.technique).joinedload(Technique.from_position),
            joinedload(Lesson.technique).joinedload(Technique.to_position),
        )
        .order_by(Lesson.order_index.asc())
    )
    if exclude_lesson_id is not None:
        q = q.filter(Lesson.id != exclude_lesson_id)
    return q.first()


def get_mission_today_response(
    db: Session,
    level: str = "beginner",
    user_id: UUID | None = None,
    review_after_days: int = 7,
    academy_id: UUID | None = None,
) -> MissionTodayResponse | None:
    """
    Retorna o payload da missão do dia pronto para o frontend (por nível).
    A-02: academy_id (ou do user) define override por academia; fallback em missão global.
    Se user_id for informado (PF-03/PF-04):
      1) Revisão: lição concluída há >= review_after_days dias.
      2) Posição difícil: lição que envolve posição com feedback de dificuldade.
      3) Senão: missão programada (academia ou global) ou fallback por nível.
    """
    resolved_academy_id = academy_id
    if resolved_academy_id is None and user_id is not None:
        user = db.query(User).filter(User.id == user_id).first()
        if user and user.academy_id is not None:
            resolved_academy_id = user.academy_id

    if user_id is not None:
        # PF-03: prioridade para revisão
        review_lesson = _get_review_lesson(db, user_id, review_after_days)
        if review_lesson:
            logger.info(
                "get_mission_today_response",
                extra={"source": "review", "lesson_id": str(review_lesson.id), "user_id": str(user_id)},
            )
            return _lesson_to_mission_today_response(
                review_lesson,
                mission_title="Revisão",
                is_review=True,
            )
        # PF-04: prioridade para posição difícil
        difficult_lesson = _get_difficult_position_lesson(db, user_id)
        if difficult_lesson:
            logger.info(
                "get_mission_today_response",
                extra={
                    "source": "difficult_position",
                    "lesson_id": str(difficult_lesson.id),
                    "user_id": str(user_id),
                },
            )
            return _lesson_to_mission_today_response(
                difficult_lesson,
                mission_title="Missão do dia",
                is_review=False,
            )

    # Missão programada (A-02: academia ou global) ou fallback
    mission = get_today_mission(db, level=level, academy_id=resolved_academy_id)
    if mission and mission.lesson:
        weekly_theme = mission.theme
        if resolved_academy_id:
            academy = db.query(Academy).filter(Academy.id == resolved_academy_id).first()
            if academy and academy.weekly_theme:
                weekly_theme = academy.weekly_theme
        logger.info("get_mission_today_response", extra={"source": "mission", "lesson_id": str(mission.lesson_id)})
        return _lesson_to_mission_today_response(mission.lesson, weekly_theme=weekly_theme)
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


def get_mission_today(
    db: Session,
    level: str = "beginner",
    academy_id: UUID | None = None,
) -> Lesson | None:
    """
    Retorna a lição do dia (compatibilidade).
    Usa get_today_mission(level, academy_id); se existir missão ativa, retorna a Lesson associada.
    """
    mission = get_today_mission(db, level=level, academy_id=academy_id)
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
