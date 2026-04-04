"""Bónus de pontos por sequência de login (múltiplos de 7 dias UTC)."""
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.models.user_login_day import UserLoginDay
from app.services.login_streak_service import login_streak_bonus_points_to_award


@pytest.mark.parametrize(
    "before,after,interval,bonus,expected",
    [
        (6, 7, 7, 50, 50),
        (13, 14, 7, 50, 50),
        (5, 6, 7, 50, 0),
        (7, 7, 7, 50, 0),
        (6, 8, 7, 50, 0),
        (6, 7, 7, 0, 0),
        (6, 7, 0, 50, 0),
    ],
)
def test_login_streak_bonus_points_to_award(before, after, interval, bonus, expected):
    assert (
        login_streak_bonus_points_to_award(before, after, interval_days=interval, bonus_points=bonus)
        == expected
    )


@pytest.mark.asyncio
async def test_login_awards_streak_bonus_on_day_7(client, db, admin_user):
    """Com 6 dias UTC prévios, o login de hoje completa 7 e devolve streak_bonus_points=50."""
    today = datetime.now(timezone.utc).date()
    for i in range(6, 0, -1):
        d = today - timedelta(days=i)
        db.add(UserLoginDay(user_id=admin_user.id, login_day=d))
    await db.commit()

    adj_before = admin_user.points_adjustment or 0
    r = await client.post(
        "/auth/login",
        json={"email": admin_user.email, "password": "admin123"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data.get("streak_bonus_points") == 50
    assert "access_token" in data

    await db.refresh(admin_user)
    assert admin_user.points_adjustment == adj_before + 50

    rows = (await db.execute(select(UserLoginDay).where(UserLoginDay.user_id == admin_user.id))).scalars().all()
    days = {row.login_day for row in rows}
    assert today in days


@pytest.mark.asyncio
async def test_login_second_same_day_no_extra_bonus(client, db, admin_user):
    """Segundo login no mesmo dia (7.º da sequência) não volta a dar bónus."""
    today = datetime.now(timezone.utc).date()
    for i in range(6, 0, -1):
        d = today - timedelta(days=i)
        db.add(UserLoginDay(user_id=admin_user.id, login_day=d))
    db.add(UserLoginDay(user_id=admin_user.id, login_day=today))
    await db.commit()

    r = await client.post(
        "/auth/login",
        json={"email": admin_user.email, "password": "admin123"},
    )
    assert r.status_code == 200
    assert r.json().get("streak_bonus_points") == 0
