"""Testes do fluxo de execuções de técnica (gamificação)."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


@pytest.fixture
async def mission_with_lesson(db, technique, academy):
    """Cria uma missão ativa com lição para testes de execução."""
    from app.models import Lesson, Mission

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Exec",
        slug=f"exec-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    mission = Mission(
        technique_id=technique.id,
        academy_id=academy.id,
        lesson_id=lesson.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
        is_active=True,
    )
    db.add(mission)
    await db.commit()
    await db.refresh(mission)
    return mission, lesson


@pytest.fixture
async def opponent_user(db, academy):
    """Cria um adversário na mesma academia."""
    from app.models import User
    from app.core.security import hash_password

    user = User(
        email=f"oponente-{uuid4().hex[:8]}@test.com",
        name="Adversário",
        role="aluno",
        graduation="blue",
        academy_id=academy.id,
        password_hash=hash_password("oponente1"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def test_criar_execucao_por_missao(client, aluno_headers, aluno_user, opponent_user, mission_with_lesson):
    mission, _ = mission_with_lesson
    r = await client.post("/executions", headers=aluno_headers, json={
        "mission_id": str(mission.id),
        "opponent_id": str(opponent_user.id),
        "usage_type": "after_training",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["status"] == "pending_confirmation"
    assert "id" in data


async def test_criar_execucao_por_tecnica(client, aluno_headers, opponent_user, mission_with_lesson):
    mission, lesson = mission_with_lesson
    r = await client.post("/executions", headers=aluno_headers, json={
        "lesson_id": str(lesson.id),
        "opponent_id": str(opponent_user.id),
        "usage_type": "before_training",
    })
    assert r.status_code == 201


async def test_listar_pendencias_oponente(client, aluno_headers, opponent_user, mission_with_lesson, db):
    from app.core.security import create_access_token

    mission, _ = mission_with_lesson
    await client.post("/executions", headers=aluno_headers, json={
        "mission_id": str(mission.id),
        "opponent_id": str(opponent_user.id),
    })

    opponent_headers = {"Authorization": f"Bearer {create_access_token(opponent_user.id)}"}
    r = await client.get("/executions/pending_confirmations", headers=opponent_headers)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_confirmar_execucao(client, aluno_headers, opponent_user, mission_with_lesson, db):
    from app.core.security import create_access_token

    mission, _ = mission_with_lesson

    create_r = await client.post("/executions", headers=aluno_headers, json={
        "mission_id": str(mission.id),
        "opponent_id": str(opponent_user.id),
    })
    execution_id = create_r.json()["id"]

    opponent_headers = {"Authorization": f"Bearer {create_access_token(opponent_user.id)}"}
    r = await client.post(f"/executions/{execution_id}/confirm", headers=opponent_headers, json={
        "outcome": "executed_successfully",
    })
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "confirmed"
    assert data["outcome"] == "executed_successfully"
    assert data["points_awarded"] >= 0


async def test_rejeitar_execucao(client, aluno_headers, opponent_user, mission_with_lesson, db):
    from app.core.security import create_access_token

    mission, _ = mission_with_lesson

    create_r = await client.post("/executions", headers=aluno_headers, json={
        "mission_id": str(mission.id),
        "opponent_id": str(opponent_user.id),
    })
    execution_id = create_r.json()["id"]

    opponent_headers = {"Authorization": f"Bearer {create_access_token(opponent_user.id)}"}
    r = await client.post(f"/executions/{execution_id}/reject", headers=opponent_headers, json={
        "reason": "dont_remember",
    })
    assert r.status_code == 200
    assert "rejected" in r.json()["status"]


async def test_minhas_execucoes(client, aluno_headers):
    r = await client.get("/executions/my_executions", headers=aluno_headers)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_contagem_pendencias(client, aluno_headers):
    r = await client.get("/executions/pending_confirmations/count", headers=aluno_headers)
    assert r.status_code == 200
    assert "count" in r.json()


async def test_execucao_sem_auth(client):
    r = await client.post("/executions", json={
        "mission_id": str(uuid4()),
        "opponent_id": str(uuid4()),
    })
    assert r.status_code == 401
