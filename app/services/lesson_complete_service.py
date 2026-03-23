import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AlreadyCompletedError, LessonNotFoundError, UserNotFoundError
from app.models import Lesson, LessonProgress, User

logger = logging.getLogger(__name__)


async def complete_lesson(db: AsyncSession, user_id: UUID, lesson_id: UUID) -> LessonProgress:
    """
    Registra conclusão da lição para o usuário.
    Valida existência de user e lesson; impede conclusão duplicada.
    """
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        logger.info("complete_lesson user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    lesson = (
        await db.execute(
            select(Lesson)
            .options(selectinload(Lesson.technique))
            .where(Lesson.id == lesson_id, Lesson.deleted_at.is_(None))
        )
    ).scalar_one_or_none()
    if not lesson:
        logger.info("complete_lesson lesson_not_found", extra={"lesson_id": str(lesson_id)})
        raise LessonNotFoundError("Lição não encontrada.")

    # Validar isolamento de academy: não-admins só podem completar lições da própria academy
    if user.role != "administrador":
        if user.academy_id is None:
            from app.core.exceptions import AppError

            raise AppError("Você precisa estar vinculado a uma academia para completar lições.", status_code=403)
        # Lição pode ter academy_id direto ou via technique.academy_id
        lesson_academy_id = lesson.academy_id or (lesson.technique.academy_id if lesson.technique else None)
        if lesson_academy_id is not None and lesson_academy_id != user.academy_id:
            from app.core.exceptions import AppError

            raise AppError("Você só pode completar lições da sua academia.", status_code=403)

    existing = (
        await db.execute(
            select(LessonProgress).where(
                LessonProgress.user_id == user_id,
                LessonProgress.lesson_id == lesson_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        logger.info("complete_lesson already_completed", extra={"user_id": str(user_id), "lesson_id": str(lesson_id)})
        raise AlreadyCompletedError("Esta lição já foi concluída por este usuário.")

    progress = LessonProgress(user_id=user_id, lesson_id=lesson_id)
    db.add(progress)
    await db.commit()
    await db.refresh(progress)

    logger.info("complete_lesson", extra={"user_id": str(user_id), "lesson_id": str(lesson_id)})
    return progress


async def is_lesson_completed(db: AsyncSession, user_id: UUID, lesson_id: UUID) -> bool:
    """Retorna True se o usuário já concluiu a lição."""
    result = (
        await db.execute(
            select(LessonProgress).where(
                LessonProgress.user_id == user_id,
                LessonProgress.lesson_id == lesson_id,
            )
        )
    ).scalar_one_or_none()
    return result is not None
