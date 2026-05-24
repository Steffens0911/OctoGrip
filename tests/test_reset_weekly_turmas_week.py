"""Reset da semana ISO atual (turmas): escolhas + conclusões na janela do fuso APP_TIMEZONE; pontos preservados."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.mark.asyncio
async def test_reset_weekly_turmas_week_requires_active_turmas(
    client: AsyncClient,
    academy,
    professor_headers: dict,
):
    r = await client.post(
        f"/academies/{academy.id}/reset_weekly_turmas_week",
        headers=professor_headers,
    )
    assert r.status_code == 400, r.text


@pytest.mark.asyncio
async def test_reset_weekly_turmas_week_clears_choice_usage_preserves_points(
    client: AsyncClient,
    db: AsyncSession,
    academy,
    professor_headers: dict,
    aluno_headers: dict,
    aluno_user,
):
    from app.models import MissionUsage, Technique, User

    t1 = Technique(
        academy_id=academy.id,
        name=f"T-reset-{uuid4().hex[:6]}",
        slug=f"t-reset-{uuid4().hex[:6]}",
        base_points=10,
    )
    db.add(t1)
    await db.commit()
    await db.refresh(t1)

    r_kit = await client.post(
        f"/academies/{academy.id}/weekly-kits",
        headers=professor_headers,
        json={
            "label": "Turma A",
            "items": [{"technique_id": str(t1.id), "multiplier": 25}],
        },
    )
    assert r_kit.status_code == 201, r_kit.text
    kit_id = r_kit.json()["id"]

    await client.put(
        "/users/me/weekly-kit-choice",
        headers=aluno_headers,
        json={"kit_id": kit_id},
    )

    missions = await client.get("/missions", headers=professor_headers)
    assert missions.status_code == 200
    m_list = [m for m in missions.json() if m.get("academy_id") == str(academy.id) and m.get("weekly_kit_id") == kit_id]
    mission_beginner = next((m for m in m_list if m.get("level") == "beginner"), None)
    assert mission_beginner is not None
    mid = mission_beginner["id"]

    ok = await client.post(
        "/mission_complete",
        headers=aluno_headers,
        json={"mission_id": str(mid), "usage_type": "after_training"},
    )
    assert ok.status_code in (200, 201), ok.text

    await db.refresh(aluno_user)
    adj_before = aluno_user.points_adjustment or 0

    usages_now = (await db.execute(select(MissionUsage).where(MissionUsage.mission_id == mid))).scalars().all()
    assert len(usages_now) >= 1
    pts_awarded = usages_now[0].points_awarded or 0

    r_reset = await client.post(
        f"/academies/{academy.id}/reset_weekly_turmas_week",
        headers=professor_headers,
    )
    assert r_reset.status_code == 200, r_reset.text
    data = r_reset.json()
    assert data.get("choices_removed", 0) >= 0

    w2 = await client.get("/mission_today/week", headers=aluno_headers)
    assert w2.status_code == 200
    assert w2.json().get("needs_kit_choice") is True

    usages_after = (await db.execute(select(MissionUsage).where(MissionUsage.mission_id == mid))).scalars().all()
    assert usages_after == []

    await db.refresh(aluno_user)
    assert (aluno_user.points_adjustment or 0) == adj_before + int(pts_awarded)

    # Conclusão fora da semana ISO atual (app) não deve ser removida pelo reset desta semana
    old_completed = datetime.now(UTC) - timedelta(days=14)
    mu_old = MissionUsage(
        user_id=aluno_user.id,
        mission_id=mid,
        lesson_id=None,
        opened_at=old_completed,
        completed_at=old_completed,
        usage_type="after_training",
        points_awarded=7,
    )
    db.add(mu_old)
    await db.commit()

    r_reset2 = await client.post(
        f"/academies/{academy.id}/reset_weekly_turmas_week",
        headers=professor_headers,
    )
    assert r_reset2.status_code == 200, r_reset2.text

    kept = (
        (
            await db.execute(
                select(MissionUsage).where(
                    MissionUsage.user_id == aluno_user.id,
                    MissionUsage.mission_id == mid,
                    MissionUsage.points_awarded == 7,
                )
            )
        )
        .scalars()
        .first()
    )
    assert kept is not None

    u_final = (await db.execute(select(User).where(User.id == aluno_user.id))).scalar_one()
    assert (u_final.points_adjustment or 0) >= adj_before + int(pts_awarded)
