"""
Testes para GET /me/training_stats — novos campos e helper _best_streak_from_distinct_days.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password_sync
from app.routes.me_training_stats import _best_streak_from_distinct_days

# ---------------------------------------------------------------------------
# Testes unitários do helper (sem banco)
# ---------------------------------------------------------------------------


class TestBestStreakFromDistinctDays:
    def test_empty_returns_zero(self):
        assert _best_streak_from_distinct_days([]) == 0

    def test_single_day_returns_one(self):
        assert _best_streak_from_distinct_days([date(2026, 1, 1)]) == 1

    def test_consecutive_days(self):
        days = [date(2026, 1, 1) + timedelta(days=i) for i in range(7)]
        assert _best_streak_from_distinct_days(days) == 7

    def test_gap_resets_streak(self):
        # 3 consecutivos, gap de 2, depois 5 consecutivos
        block1 = [date(2026, 1, 1) + timedelta(days=i) for i in range(3)]
        block2 = [date(2026, 1, 10) + timedelta(days=i) for i in range(5)]
        assert _best_streak_from_distinct_days(block1 + block2) == 5

    def test_duplicate_days_ignored(self):
        days = [date(2026, 1, 1), date(2026, 1, 1), date(2026, 1, 2)]
        assert _best_streak_from_distinct_days(days) == 2

    def test_order_does_not_matter(self):
        days = [date(2026, 1, 3), date(2026, 1, 1), date(2026, 1, 2)]
        assert _best_streak_from_distinct_days(days) == 3

    def test_two_equal_blocks_returns_max(self):
        block1 = [date(2026, 1, 1) + timedelta(days=i) for i in range(4)]
        block2 = [date(2026, 2, 1) + timedelta(days=i) for i in range(4)]
        assert _best_streak_from_distinct_days(block1 + block2) == 4


# ---------------------------------------------------------------------------
# Fixtures locais
# ---------------------------------------------------------------------------


@pytest.fixture
async def ts_academy(db: AsyncSession):
    from app.models import Academy

    a = Academy(
        name=f"Academia TS {uuid4().hex[:6]}",
        slug=f"ts-{uuid4().hex[:6]}",
    )
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


@pytest.fixture
async def ts_aluno(db: AsyncSession, ts_academy):
    from app.models import User

    u = User(
        email=f"aluno-ts-{uuid4().hex[:8]}@test.com",
        name="Aluno TS",
        role="aluno",
        graduation="white",
        academy_id=ts_academy.id,
        password_hash=hash_password_sync("aluno123"),
        punctuality_streak=3,
        punctuality_streak_best=10,
    )
    db.add(u)
    await db.commit()
    await db.refresh(u)
    return u


@pytest.fixture
def ts_headers(ts_aluno):
    return {"Authorization": f"Bearer {create_access_token(ts_aluno.id)}"}


# ---------------------------------------------------------------------------
# Testes de integração do endpoint
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_training_stats_returns_new_fields(client, ts_aluno, ts_headers):
    """Endpoint retorna todos os campos novos com valores válidos."""
    r = client.get("/me/training_stats", headers=ts_headers)
    assert r.status_code == 200
    data = r.json()

    # campos existentes ainda presentes
    assert "workouts_last_30_days" in data
    assert "positions_total" in data

    # novos campos presentes
    assert "videos_total" in data
    assert "trophies_total" in data
    assert "total_xp" in data
    assert "login_streak_current" in data
    assert "login_streak_best" in data
    assert "punctuality_streak" in data
    assert "punctuality_streak_best" in data

    # sem dados: valores zerados, rankings None
    assert data["videos_total"] == 0
    assert data["trophies_total"] == 0
    assert data["total_xp"] == 0
    assert data["login_streak_current"] == 0
    assert data["login_streak_best"] == 0


@pytest.mark.asyncio
async def test_training_stats_punctuality_from_user(client, ts_aluno, ts_headers):
    """Streak e recorde de pontualidade vêm do campo armazenado no User."""
    r = client.get("/me/training_stats", headers=ts_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["punctuality_streak"] == ts_aluno.punctuality_streak
    assert data["punctuality_streak_best"] == ts_aluno.punctuality_streak_best


@pytest.mark.asyncio
async def test_training_stats_login_streak_from_login_days(client, db, ts_aluno, ts_headers):
    """login_streak_current reflete os dias reais de login registrados."""
    from app.models.user_login_day import UserLoginDay

    today = date.today()
    for delta in range(3):
        db.add(UserLoginDay(user_id=ts_aluno.id, login_day=today - timedelta(days=delta)))
    await db.commit()

    r = client.get("/me/training_stats", headers=ts_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["login_streak_current"] == 3
    assert data["login_streak_best"] == 3


@pytest.mark.asyncio
async def test_training_stats_ranking_xp_with_academy(client, db, ts_academy, ts_aluno, ts_headers):
    """Ranking de XP é calculado quando aluno pertence a uma academia."""
    r = client.get("/me/training_stats", headers=ts_headers)
    assert r.status_code == 200
    data = r.json()
    # Com apenas 1 aluno na academia, ranking deve ser 1
    assert data["ranking_xp"] == 1
    assert data["ranking_xp_out_of"] == 1


@pytest.mark.asyncio
async def test_training_stats_ranking_punctuality(client, db, ts_academy, ts_aluno, ts_headers):
    """Ranking de pontualidade é retornado corretamente."""
    r = client.get("/me/training_stats", headers=ts_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["ranking_punctuality"] == 1
    assert data["ranking_punctuality_out_of"] == 1
