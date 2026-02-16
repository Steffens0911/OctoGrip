"""Conclusão por missão: registra que o usuário concluiu a missão do dia."""
import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.exceptions import UserNotFoundError
from app.core.graduation import points_for_graduation
from app.models import Mission, MissionUsage, User

logger = logging.getLogger(__name__)


def complete_mission(
    db: Session,
    user_id: UUID,
    mission_id: UUID,
    *,
    usage_type: str = "after_training",
) -> MissionUsage:
    """
    Registra conclusão da missão pelo usuário (conclusão por missão).
    Um usuário pode concluir a mesma missão apenas uma vez (409 se já concluiu).
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        logger.info("complete_mission user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    mission = db.query(Mission).filter(Mission.id == mission_id).first()
    if not mission:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Missão não encontrada.")

    existing = (
        db.query(MissionUsage)
        .filter(
            MissionUsage.user_id == user_id,
            MissionUsage.mission_id == mission_id,
        )
        .first()
    )
    if existing:
        from app.core.exceptions import AlreadyCompletedError

        logger.info(
            "complete_mission already_completed",
            extra={"user_id": str(user_id), "mission_id": str(mission_id)},
        )
        raise AlreadyCompletedError("Esta missão já foi concluída por este usuário.")

    if usage_type not in ("before_training", "after_training"):
        usage_type = "after_training"
    # Pontos = faixa do aluno: ×1 branca, ×2 azul, ×3 roxa (marrom=4, preta=5)
    points_awarded = points_for_graduation(user.graduation)
    now = datetime.now(timezone.utc)
    usage = MissionUsage(
        user_id=user_id,
        mission_id=mission_id,
        lesson_id=None,
        opened_at=now,
        completed_at=now,
        usage_type=usage_type,
        points_awarded=points_awarded,
    )
    db.add(usage)
    db.commit()
    db.refresh(usage)
    logger.info("complete_mission", extra={"user_id": str(user_id), "mission_id": str(mission_id)})
    return usage
