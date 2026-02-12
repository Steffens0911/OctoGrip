import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.exceptions import PositionNotFoundError, UserNotFoundError
from app.models import Position, TrainingFeedback, User

logger = logging.getLogger(__name__)


def create_feedback(
    db: Session,
    user_id: UUID,
    position_id: UUID,
    observation: str | None = None,
) -> TrainingFeedback:
    """
    Registra feedback de treino: posição em que o usuário teve dificuldade.
    Preparado para análises futuras (difficulty_level fixo por enquanto).
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        logger.info("create_feedback user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    position = db.query(Position).filter(Position.id == position_id).first()
    if not position:
        logger.info("create_feedback position_not_found", extra={"position_id": str(position_id)})
        raise PositionNotFoundError("Posição não encontrada.")

    feedback = TrainingFeedback(
        user_id=user_id,
        position_id=position_id,
        difficulty_level=1,  # fixo por enquanto; futuras análises podem usar escala
        note=observation,
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)
    logger.info("create_feedback", extra={"user_id": str(user_id), "position_id": str(position_id)})
    return feedback
