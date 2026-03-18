import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import UserNotFoundError
from app.models import TrainingFeedback, User

logger = logging.getLogger(__name__)


async def create_feedback(
    db: AsyncSession,
    user_id: UUID,
    observation: str | None = None,
) -> TrainingFeedback:
    """
    Registra feedback de treino textual do usuário (sem Position).
    Preparado para análises futuras (difficulty_level fixo por enquanto: 1).
    """
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        logger.info("create_feedback user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    feedback = TrainingFeedback(
        user_id=user_id,
        difficulty_level=1,
        note=observation,
    )
    db.add(feedback)
    await db.commit()
    await db.refresh(feedback)
    logger.info("create_feedback", extra={"user_id": str(user_id)})
    return feedback
