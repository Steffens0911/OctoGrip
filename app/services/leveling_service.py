"""Serviço de atualização do level do usuário com base no total de pontos."""

from __future__ import annotations

import logging
from typing import Optional, Tuple
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import UserNotFoundError
from app.core.leveling import compute_level_from_total_points
from app.models import User

logger = logging.getLogger(__name__)


async def refresh_user_level(
    db: AsyncSession,
    user_id: UUID,
    *,
    total_points: Optional[int] = None,
) -> Tuple[int, int, int]:
    """Recalcula e persiste (reward_level, reward_level_points) do usuário.

    Retorna (level, level_points, next_level_threshold).
    """
    if total_points is None:
        from app.services.execution_service import total_points_for_user

        total_points = await total_points_for_user(db, user_id)

    level, level_points, next_threshold = compute_level_from_total_points(total_points)

    # Lock para evitar corrida quando múltiplas pontuações ocorrem em sequência.
    stmt = select(User).where(User.id == user_id).with_for_update()
    user = (await db.execute(stmt)).scalar_one_or_none()
    if not user:
        raise UserNotFoundError("Usuário não encontrado.")

    if user.reward_level != level or user.reward_level_points != level_points:
        user.reward_level = level
        user.reward_level_points = level_points
        await db.commit()
        await db.refresh(user)

    logger.debug(
        "refresh_user_level",
        extra={
            "user_id": str(user_id),
            "total_points": total_points,
            "reward_level": level,
            "reward_level_points": level_points,
            "next_level_threshold": next_threshold,
        },
    )

    return level, level_points, next_threshold

