"""Conclusão por missão: registra que o usuário concluiu a missão do dia."""
import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import UserNotFoundError
from app.core.points_limits import clamp_reward_points
from app.models import Mission, MissionUsage, User
from app.services.leveling_service import refresh_user_level

logger = logging.getLogger(__name__)


async def complete_mission(
    db: AsyncSession,
    user_id: UUID,
    mission_id: UUID,
    *,
    usage_type: str = "after_training",
) -> MissionUsage:
    """
    Registra conclusão da missão pelo usuário (conclusão por missão).
    Um usuário pode concluir a mesma missão apenas uma vez (409 se já concluiu).
    """
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        logger.info("complete_mission user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    mission = (await db.execute(select(Mission).where(Mission.id == mission_id))).scalar_one_or_none()
    if not mission:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Missão não encontrada.")

    # Validar isolamento de academy: não-admins só podem completar missões da própria academy
    if user.role != "administrador":
        if user.academy_id is None:
            from app.core.exceptions import AppError

            raise AppError("Você precisa estar vinculado a uma academia para completar missões.", status_code=403)
        if mission.academy_id is not None and mission.academy_id != user.academy_id:
            from app.core.exceptions import AppError

            raise AppError("Você só pode completar missões da sua academia.", status_code=403)

    existing = (
        await db.execute(
            select(MissionUsage).where(
                MissionUsage.user_id == user_id,
                MissionUsage.mission_id == mission_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        from app.core.exceptions import AlreadyCompletedError

        logger.info(
            "complete_mission already_completed",
            extra={"user_id": str(user_id), "mission_id": str(mission_id)},
        )
        raise AlreadyCompletedError("Esta missão já foi concluída por este usuário.")

    if usage_type not in ("before_training", "after_training"):
        usage_type = "after_training"
    points_awarded = clamp_reward_points(mission.multiplier)
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
    await db.commit()
    await db.refresh(usage)

    # Atualiza o level imediatamente após pontuar.
    await refresh_user_level(db, user_id)

    logger.info("complete_mission", extra={"user_id": str(user_id), "mission_id": str(mission_id)})
    return usage
