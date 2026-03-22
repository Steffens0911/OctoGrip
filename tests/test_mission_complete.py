"""Testes de conclusão de missão."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


@pytest.fixture
async def mission_ativa(db, academy, technique):
    """Cria uma missão ativa para testes."""
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


async def test_completar_missao(client, aluno_headers, aluno_user, mission_ativa):
    """Completar missão com sucesso."""
    r = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission_ativa.id),
        "usage_type": "after_training",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["user_id"] == str(aluno_user.id)
    assert data["mission_id"] == str(mission_ativa.id)
    assert "completed_at" in data


async def test_completar_missao_pontos_iguais_ao_multiplier(
    client, aluno_headers, aluno_user, db, academy, technique,
):
    """Ao concluir, os pontos creditados = mission.multiplier (faixa 10–50)."""
    from app.models import Mission

    mission = Mission(
        academy_id=academy.id,
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
        is_active=True,
        multiplier=35,
    )
    db.add(mission)
    await db.commit()
    await db.refresh(mission)

    r0 = await client.get(f"/users/{aluno_user.id}/points", headers=aluno_headers)
    assert r0.status_code == 200
    antes = r0.json()["points"]

    r = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission.id),
        "usage_type": "after_training",
    })
    assert r.status_code == 201

    r1 = await client.get(f"/users/{aluno_user.id}/points", headers=aluno_headers)
    assert r1.status_code == 200
    assert r1.json()["points"] == antes + 35


async def test_completar_missao_before_training(client, aluno_headers, aluno_user, mission_ativa):
    """Completar missão com usage_type before_training."""
    r = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission_ativa.id),
        "usage_type": "before_training",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["mission_id"] == str(mission_ativa.id)


async def test_completar_missao_duplicada(client, aluno_headers, aluno_user, mission_ativa):
    """Tentar completar missão duas vezes retorna 409."""
    # Primeira conclusão
    r1 = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission_ativa.id),
    })
    assert r1.status_code == 201

    # Segunda conclusão (deve falhar)
    r2 = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission_ativa.id),
    })
    assert r2.status_code == 409


async def test_completar_missao_inexistente(client, aluno_headers):
    """Completar missão inexistente retorna 404."""
    fake_mission_id = uuid4()
    r = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(fake_mission_id),
    })
    assert r.status_code == 404


async def test_completar_missao_sem_auth(client, mission_ativa):
    """Completar missão sem autenticação retorna 401."""
    r = await client.post("/mission_complete", json={
        "mission_id": str(mission_ativa.id),
    })
    assert r.status_code == 401


async def test_completar_missao_usage_type_invalido(client, aluno_headers, mission_ativa):
    """Usage_type inválido é tratado como after_training."""
    r = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission_ativa.id),
        "usage_type": "invalid_type",
    })
    # Deve aceitar mas tratar como after_training
    assert r.status_code == 201


async def test_completar_missao_multiplos_usuarios(client, db, academy, mission_ativa):
    """Múltiplos usuários podem completar a mesma missão."""
    from app.models import User
    from app.core.security import create_access_token, hash_password_sync

    # Criar segundo usuário
    user2 = User(
        email=f"aluno2-{uuid4().hex[:8]}@test.com",
        name="Aluno 2",
        role="aluno",
        graduation="white",
        academy_id=academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add(user2)
    await db.commit()
    await db.refresh(user2)

    headers1 = {"Authorization": f"Bearer {create_access_token(user2.id)}"}

    # Primeiro usuário completa
    r1 = await client.post("/mission_complete", headers=headers1, json={
        "mission_id": str(mission_ativa.id),
    })
    assert r1.status_code == 201

    # Segundo usuário também pode completar
    user3 = User(
        email=f"aluno3-{uuid4().hex[:8]}@test.com",
        name="Aluno 3",
        role="aluno",
        graduation="white",
        academy_id=academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add(user3)
    await db.commit()
    await db.refresh(user3)

    headers2 = {"Authorization": f"Bearer {create_access_token(user3.id)}"}
    r2 = await client.post("/mission_complete", headers=headers2, json={
        "mission_id": str(mission_ativa.id),
    })
    assert r2.status_code == 201
