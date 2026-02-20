import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import PositionNotFoundError, UserNotFoundError
from app.models import Position, TrainingFeedback, User

logger = logging.getLogger(__name__)


async def create_feedback(
    db: AsyncSession,
    user_id: UUID,
    position_id: UUID,
    observation: str | None = None,
) -> TrainingFeedback:
    """
    Registra feedback de treino: posição em que o usuário teve dificuldade.
    Preparado para análises futuras (difficulty_level fixo por enquanto).
    """
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        logger.info("create_feedback user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    position = (await db.execute(select(Position).where(Position.id == position_id))).scalar_one_or_none()
    if not position:
        logger.info("create_feedback position_not_found", extra={"position_id": str(position_id)})
        raise PositionNotFoundError("Posição não encontrada.")

    feedback = TrainingFeedback(
        user_id=user_id,
        position_id=position_id,
        difficulty_level=1,
        note=observation,
    )
    db.add(feedback)
    await db.commit()
    await db.refresh(feedback)
    logger.info("create_feedback", extra={"user_id": str(user_id), "position_id": str(position_id)})
    return feedback
