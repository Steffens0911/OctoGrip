import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.exceptions import AlreadyCompletedError, LessonNotFoundError, UserNotFoundError
from app.models import Lesson, LessonProgress, User

logger = logging.getLogger(__name__)


def complete_lesson(db: Session, user_id: UUID, lesson_id: UUID) -> LessonProgress:
    """
    Registra conclusão da lição para o usuário.
    Valida existência de user e lesson; impede conclusão duplicada.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        logger.info("complete_lesson user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    lesson = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not lesson:
        logger.info("complete_lesson lesson_not_found", extra={"lesson_id": str(lesson_id)})
        raise LessonNotFoundError("Lição não encontrada.")

    existing = (
        db.query(LessonProgress)
        .filter(
            LessonProgress.user_id == user_id,
            LessonProgress.lesson_id == lesson_id,
        )
        .first()
    )
    if existing:
        logger.info("complete_lesson already_completed", extra={"user_id": str(user_id), "lesson_id": str(lesson_id)})
        raise AlreadyCompletedError("Esta lição já foi concluída por este usuário.")

    progress = LessonProgress(user_id=user_id, lesson_id=lesson_id)
    db.add(progress)
    db.commit()
    db.refresh(progress)
    logger.info("complete_lesson", extra={"user_id": str(user_id), "lesson_id": str(lesson_id)})
    return progress
