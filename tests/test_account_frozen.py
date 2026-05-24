"""Conta congelada: PATCH pelo admin/gestor e bloqueio de escrita para aluno."""

from datetime import date, timedelta

import pytest


@pytest.fixture
async def mission_ativa(db, academy, technique):
    from app.models import Mission

    mission = Mission(
        academy_id=academy.id,
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
        is_active=True,
    )
    db.add(mission)
    await db.commit()
    await db.refresh(mission)
    return mission


async def test_admin_congela_aluno_me_retorna_flags(client, admin_headers, aluno_user, aluno_headers):
    r = await client.patch(
        f"/users/{aluno_user.id}",
        headers=admin_headers,
        json={
            "account_frozen": True,
            "account_freeze_reason": "Mensalidade em atraso",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert data["account_frozen"] is True
    assert data["account_freeze_reason"] == "Mensalidade em atraso"

    me = await client.get("/auth/me", headers=aluno_headers)
    assert me.status_code == 200
    body = me.json()
    assert body["account_frozen"] is True
    assert body["account_freeze_reason"] == "Mensalidade em atraso"


async def test_aluno_congelado_nao_completa_missao(client, admin_headers, aluno_headers, aluno_user, mission_ativa):
    await client.patch(
        f"/users/{aluno_user.id}",
        headers=admin_headers,
        json={"account_frozen": True, "account_freeze_reason": "Teste"},
    )
    r = await client.post(
        "/mission_complete",
        headers=aluno_headers,
        json={
            "mission_id": str(mission_ativa.id),
            "usage_type": "after_training",
        },
    )
    assert r.status_code == 403
    err = r.json()
    assert err.get("error", {}).get("type") == "AccountFrozenError"


async def test_gerente_congela_somente_aluno_da_academia(client, gerente_headers, aluno_user):
    r = await client.patch(
        f"/users/{aluno_user.id}",
        headers=gerente_headers,
        json={"account_frozen": True},
    )
    assert r.status_code == 200
    assert r.json()["account_frozen"] is True


async def test_professor_nao_altera_congelamento(client, professor_headers, aluno_user, db):
    from sqlalchemy import select

    from app.models import User

    r = await client.patch(
        f"/users/{aluno_user.id}",
        headers=professor_headers,
        json={"account_frozen": True, "account_freeze_reason": "x"},
    )
    assert r.status_code == 200
    assert r.json().get("account_frozen") is False
    row = (await db.execute(select(User).where(User.id == aluno_user.id))).scalar_one()
    assert row.account_frozen is False
