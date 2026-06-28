"""
Lógica de pontualidade: compara o instante de check-in com o horário de início
do TrainingSession vinculado à chamada.

Regras acordadas:
- Pontual = check-in <= start_time do treino (exato no limite, não há grace period)
- Atrasado = check-in > start_time → zera streak imediatamente
- Ausente = não registrou presença → não afeta o streak
"""
from __future__ import annotations

import logging
from datetime import UTC, datetime
from datetime import time as dt_time

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_time import get_app_tz
from app.models import Academy, User
from app.models.attendance_record import AttendanceRecord
from app.models.training_session import TrainingSession

logger = logging.getLogger(__name__)


async def apply_punctuality(
    db: AsyncSession,
    *,
    user: User,
    academy: Academy,
    record: AttendanceRecord,
    training_session: TrainingSession,
    checked_in_at: datetime,
) -> tuple[bool, int]:
    """
    Determina pontualidade, atualiza streak e concede XP.

    Retorna (was_punctual, xp_awarded).
    Não faz commit — o chamador é responsável.
    """
    tz = get_app_tz()

    h, m = map(int, training_session.start_time.split(":"))
    start_dt_local = datetime.combine(
        training_session.class_date,
        dt_time(h, m, 0),
        tzinfo=tz,
    )
    start_dt_utc = start_dt_local.astimezone(UTC)

    if checked_in_at.tzinfo is None:
        checked_in_at = checked_in_at.replace(tzinfo=UTC)

    was_punctual = checked_in_at <= start_dt_utc
    record.was_punctual = was_punctual

    xp_awarded = 0
    if was_punctual:
        new_streak = (user.punctuality_streak or 0) + 1
        user.punctuality_streak = new_streak
        if new_streak > (user.punctuality_streak_best or 0):
            user.punctuality_streak_best = new_streak

        xp = academy.punctuality_xp if academy.punctuality_xp is not None else 15
        user.points_adjustment = (user.points_adjustment or 0) + xp
        xp_awarded = xp

        logger.info(
            "punctuality_awarded",
            extra={
                "user_id": str(user.id),
                "training_session_id": str(training_session.id),
                "streak": new_streak,
                "xp": xp,
            },
        )
    else:
        user.punctuality_streak = 0
        logger.info(
            "punctuality_streak_reset",
            extra={
                "user_id": str(user.id),
                "training_session_id": str(training_session.id),
                "checked_in_at_utc": checked_in_at.isoformat(),
                "start_dt_utc": start_dt_utc.isoformat(),
            },
        )

    return was_punctual, xp_awarded
