"""Testes da lógica de sequência de login (UTC)."""
from datetime import date, timedelta

import pytest

from app.services.login_streak_service import login_streak_from_distinct_days


def test_streak_empty():
    assert login_streak_from_distinct_days([], date(2026, 4, 1)) == 0


def test_streak_today_only():
    d = date(2026, 4, 3)
    assert login_streak_from_distinct_days([d], d) == 1


def test_streak_three_consecutive_from_today():
    today = date(2026, 4, 3)
    days = [today, today - timedelta(days=1), today - timedelta(days=2)]
    days.sort(reverse=True)
    assert login_streak_from_distinct_days(days, today) == 3


def test_streak_grace_yesterday_no_today():
    """Hoje sem login, ontem com login: sequência ainda conta a partir de ontem."""
    today = date(2026, 4, 3)
    yesterday = today - timedelta(days=1)
    days = [yesterday, yesterday - timedelta(days=1)]
    days.sort(reverse=True)
    assert login_streak_from_distinct_days(days, today) == 2


def test_streak_broken_gap():
    today = date(2026, 4, 3)
    # Só há login há 2 dias — sem ontem nem hoje
    days = [today - timedelta(days=2)]
    assert login_streak_from_distinct_days(days, today) == 0


@pytest.mark.asyncio
async def test_login_then_me_has_streak(client, admin_user):
    r = await client.post(
        "/auth/login",
        json={"email": admin_user.email, "password": "admin123"},
    )
    assert r.status_code == 200
    token = r.json()["access_token"]
    me = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    data = me.json()
    assert "login_streak_days" in data
    assert isinstance(data["login_streak_days"], int)
    assert data["login_streak_days"] >= 1
