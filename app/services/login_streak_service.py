"""Sequência de dias consecutivos com login (UTC), persistida em user_login_days."""
from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import User
from app.models.user_login_day import UserLoginDay
from app.schemas.user import UserRead

logger = logging.getLogger(__name__)

# Limite de dias distintos a carregar (performance).
_MAX_DISTINCT_DAYS = 400


def login_streak_from_distinct_days(
    login_days_desc: list[date],
    today_utc: date,
) -> int:
    """
    Conta dias consecutivos com login a partir de today_utc ou ontem (UTC).

    Se hoje ainda não há login, mas ontem há, a sequência mantém-se até ao fim
    do dia UTC sem novo login.
    """
    if not login_days_desc:
        return 0
    day_set = set(login_days_desc)
    if today_utc in day_set:
        d = today_utc
    elif (today_utc - timedelta(days=1)) in day_set:
        d = today_utc - timedelta(days=1)
    else:
        return 0
    count = 0
    while d in day_set:
        count += 1
        d -= timedelta(days=1)
    return count


def login_streak_bonus_points_to_award(
    streak_before: int,
    streak_after: int,
    *,
    interval_days: int,
    bonus_points: int,
) -> int:
    """
    Retorna bonus_points se o login completou um múltiplo de interval_days na sequência
    (ex.: 7, 14, 21) e o contador subiu exatamente 1 (evita duplicar no 2.º login do mesmo dia).
    """
    if interval_days <= 0 or bonus_points <= 0:
        return 0
    if streak_after != streak_before + 1:
        return 0
    if streak_after < interval_days or streak_after % interval_days != 0:
        return 0
    return bonus_points


async def apply_login_streak_bonus(
    db: AsyncSession,
    user: User,
    *,
    now: datetime | None = None,
) -> int:
    """
    Regista o dia UTC de login e, se aplicável, credita LOGIN_STREAK_BONUS_POINTS em points_adjustment.
    Não faz commit. Retorna pontos concedidos (0 ou o bónus).
    """
    dt = now if now is not None else datetime.now(timezone.utc)
    day = dt.date()
    streak_before = await compute_login_streak_days(db, user.id, today_utc=day)
    await record_login_day(db, user.id, now=dt)
    await db.flush()
    streak_after = await compute_login_streak_days(db, user.id, today_utc=day)
    bonus = login_streak_bonus_points_to_award(
        streak_before,
        streak_after,
        interval_days=settings.LOGIN_STREAK_BONUS_INTERVAL_DAYS,
        bonus_points=settings.LOGIN_STREAK_BONUS_POINTS,
    )
    if bonus > 0:
        user.points_adjustment = (user.points_adjustment or 0) + bonus
        logger.info(
            "login_streak_bonus_awarded",
            extra={
                "user_id": str(user.id),
                "streak_after": streak_after,
                "bonus_points": bonus,
            },
        )
    return bonus


async def record_login_day(db: AsyncSession, user_id: uuid.UUID, *, now: datetime | None = None) -> None:
    """Regista o dia UTC atual como dia de login (idempotente por dia)."""
    dt = now if now is not None else datetime.now(timezone.utc)
    day = dt.date()
    stmt = (
        insert(UserLoginDay)
        .values(user_id=user_id, login_day=day)
        .on_conflict_do_nothing()
    )
    await db.execute(stmt)


async def compute_login_streak_days(
    db: AsyncSession,
    user_id: uuid.UUID,
    *,
    today_utc: date | None = None,
) -> int:
    today = today_utc if today_utc is not None else datetime.now(timezone.utc).date()
    result = await db.execute(
        select(UserLoginDay.login_day)
        .where(UserLoginDay.user_id == user_id)
        .order_by(UserLoginDay.login_day.desc())
        .limit(_MAX_DISTINCT_DAYS)
    )
    rows = result.scalars().all()
    return login_streak_from_distinct_days(list(rows), today)


async def user_read_with_login_streak(db: AsyncSession, user: User) -> UserRead:
    streak = await compute_login_streak_days(db, user.id)
    return UserRead.model_validate(user).model_copy(update={"login_streak_days": streak})
