"""Testes do fluxo de execuções de técnica (gamificação)."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


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
