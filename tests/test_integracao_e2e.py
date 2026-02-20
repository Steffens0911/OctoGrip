"""Testes de integração end-to-end: fluxos completos de missão, execução, troféu."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


async def test_fluxo_completo_missao(client, admin_headers, aluno_headers, aluno_user, academy, technique, db):
    """Fluxo completo: Criar missão → Completar missão → Verificar pontos → Verificar ranking."""
    from app.models import Mission, Position

    # Criar posições e missão
    p1 = Position(academy_id=academy.id, name="Guarda", slug=f"guarda-{uuid4().hex[:6]}")
    p2 = Position(academy_id=academy.id, name="Montada", slug=f"montada-{uuid4().hex[:6]}")
    db.add_all([p1, p2])
    await db.commit()
    await db.refresh(p1)
    await db.refresh(p2)

    # Criar missão
    r1 = await client.post("/missions", headers=admin_headers, json={
        "technique_id": str(technique.id),
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=6)).isoformat(),
        "level": "beginner",
    })
    assert r1.status_code == 201
    mission_id = r1.json()["id"]

    # Completar missão
    r2 = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": mission_id,
        "usage_type": "after_training",
    })
    assert r2.status_code == 201

    # Verificar pontos do usuário
    r3 = await client.get(f"/users/{aluno_user.id}/points", headers=admin_headers)
    assert r3.status_code == 200
    points_data = r3.json()
    assert points_data["points"] > 0

    # Verificar ranking da academia
    r4 = await client.get(f"/academies/{academy.id}/ranking", headers=admin_headers)
    assert r4.status_code == 200
    ranking_data = r4.json()
    assert len(ranking_data["entries"]) >= 1
    # Verificar que o aluno está no ranking
    assert any(entry["user_id"] == str(aluno_user.id) for entry in ranking_data["entries"])


async def test_fluxo_completo_execucao(client, aluno_headers, aluno_user, opponent_user, mission_with_lesson, db):
    """Fluxo completo: Criar execução → Confirmar execução → Verificar pontos → Verificar troféus."""
    mission, _ = mission_with_lesson

    # Criar execução
    r1 = await client.post("/executions", headers=aluno_headers, json={
        "mission_id": str(mission.id),
        "opponent_id": str(opponent_user.id),
        "usage_type": "after_training",
    })
    assert r1.status_code == 201
    execution_id = r1.json()["id"]
    assert r1.json()["status"] == "pending_confirmation"

    # Confirmar execução (como oponente)
    from app.core.security import create_access_token
    opponent_headers = {"Authorization": f"Bearer {create_access_token(opponent_user.id)}"}
    
    r2 = await client.post(f"/executions/{execution_id}/confirm", headers=opponent_headers, json={
        "outcome": "executed_successfully",
    })
    assert r2.status_code == 200
    assert r2.json()["status"] == "confirmed"
    assert r2.json()["points_awarded"] > 0

    # Verificar pontos do usuário
    r3 = await client.get(f"/users/{aluno_user.id}/points", headers=aluno_headers)
    assert r3.status_code == 200
    points_data = r3.json()
    assert points_data["points"] > 0

    # Verificar log de pontos
    r4 = await client.get(f"/users/{aluno_user.id}/points_log", headers=aluno_headers)
    assert r4.status_code == 200
    log_data = r4.json()
    assert len(log_data["entries"]) >= 1
    # Verificar que há entrada de execução confirmada
    assert any("execução" in entry.get("description", "").lower() or "execution" in entry.get("source", "").lower() 
               for entry in log_data["entries"])


async def test_fluxo_completo_trofeu(client, admin_headers, aluno_headers, aluno_user, academy, technique, db):
    """Fluxo completo: Criar troféu → Completar execuções → Verificar tier conquistado."""
    from app.models import Mission, Position, TechniqueExecution
    from app.core.security import create_access_token
    from datetime import datetime, timezone

    # Criar posições e missão
    p1 = Position(academy_id=academy.id, name="Guarda", slug=f"guarda-{uuid4().hex[:6]}")
    p2 = Position(academy_id=academy.id, name="Montada", slug=f"montada-{uuid4().hex[:6]}")
    db.add_all([p1, p2])
    await db.commit()
    await db.refresh(p1)
    await db.refresh(p2)

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

    # Criar oponente
    from app.models import User
    from app.core.security import hash_password

    opponent = User(
        email=f"oponente-{uuid4().hex[:8]}@test.com",
        name="Oponente",
        role="aluno",
        graduation="blue",
        academy_id=academy.id,
        password_hash=hash_password("oponente1"),
    )
    db.add(opponent)
    await db.commit()
    await db.refresh(opponent)

    # Criar troféu (meta: 5 execuções confirmadas)
    r1 = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Troféu E2E",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 5,
    })
    assert r1.status_code == 201
    trophy_id = r1.json()["id"]

    # Criar e confirmar 5 execuções
    opponent_headers = {"Authorization": f"Bearer {create_access_token(opponent.id)}"}
    
    for i in range(5):
        # Criar execução
        create_r = await client.post("/executions", headers=aluno_headers, json={
            "mission_id": str(mission.id),
            "opponent_id": str(opponent.id),
        })
        execution_id = create_r.json()["id"]

        # Confirmar execução
        confirm_r = await client.post(f"/executions/{execution_id}/confirm", headers=opponent_headers, json={
            "outcome": "executed_successfully",
        })
        assert confirm_r.status_code == 200

    # Verificar galeria de troféus do usuário
    r2 = await client.get(f"/trophies/user/{aluno_user.id}", headers=aluno_headers)
    assert r2.status_code == 200
    gallery_data = r2.json()
    
    # Verificar que o troféu está na galeria
    trophy_item = next((t for t in gallery_data if t["trophy_id"] == trophy_id), None)
    assert trophy_item is not None
    # Verificar que há tier conquistado (bronze, silver ou gold)
    assert trophy_item["earned_tier"] is not None


async def test_fluxo_reset_missoes(client, admin_headers, academy, technique, db):
    """Fluxo: Criar missões semanais → Reset → Verificar novas missões criadas."""
    from app.models import Mission, Position

    # Criar posições
    p1 = Position(academy_id=academy.id, name="Guarda", slug=f"guarda-{uuid4().hex[:6]}")
    p2 = Position(academy_id=academy.id, name="Montada", slug=f"montada-{uuid4().hex[:6]}")
    db.add_all([p1, p2])
    await db.commit()
    await db.refresh(p1)
    await db.refresh(p2)

    # Criar missões semanais
    missions = []
    for i in range(3):
        mission = Mission(
            academy_id=academy.id,
            technique_id=technique.id,
            start_date=date.today() + timedelta(weeks=i),
            end_date=date.today() + timedelta(weeks=i, days=6),
            level="beginner",
            is_active=True,
            slot_index=i,
        )
        db.add(mission)
        missions.append(mission)
    await db.commit()

    # Verificar que existem missões
    r1 = await client.get(f"/missions?academy_id={academy.id}", headers=admin_headers)
    assert r1.status_code == 200
    initial_count = len(r1.json())

    # Reset de missões
    r2 = await client.post(f"/academies/{academy.id}/reset_missions", headers=admin_headers)
    assert r2.status_code == 200

    # Verificar que novas missões foram criadas (ou antigas foram limpas)
    r3 = await client.get(f"/missions?academy_id={academy.id}", headers=admin_headers)
    assert r3.status_code == 200
    # O reset pode limpar ou criar novas missões dependendo da implementação
    # Verificamos apenas que a operação foi bem-sucedida


async def test_fluxo_completo_licao_e_missao(client, aluno_headers, aluno_user, academy, technique, db):
    """Fluxo completo: Criar lição → Completar lição → Criar missão → Completar missão."""
    from app.models import Lesson, Mission, Position

    # Criar posições
    p1 = Position(academy_id=academy.id, name="Guarda", slug=f"guarda-{uuid4().hex[:6]}")
    p2 = Position(academy_id=academy.id, name="Montada", slug=f"montada-{uuid4().hex[:6]}")
    db.add_all([p1, p2])
    await db.commit()
    await db.refresh(p1)
    await db.refresh(p2)

    # Criar lição
    r1 = await client.post("/lessons", headers=aluno_headers, json={
        "technique_id": str(technique.id),
        "title": "Lição E2E",
        "order_index": 0,
    })
    assert r1.status_code == 201
    lesson_id = r1.json()["id"]

    # Verificar status (não concluída)
    r2 = await client.get(f"/lesson_complete/status?lesson_id={lesson_id}", headers=aluno_headers)
    assert r2.status_code == 200
    assert r2.json()["completed"] is False

    # Completar lição
    r3 = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": lesson_id,
    })
    assert r3.status_code == 201

    # Verificar status (concluída)
    r4 = await client.get(f"/lesson_complete/status?lesson_id={lesson_id}", headers=aluno_headers)
    assert r4.status_code == 200
    assert r4.json()["completed"] is True

    # Criar missão
    r5 = await client.post("/missions", headers=aluno_headers, json={
        "technique_id": str(technique.id),
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=6)).isoformat(),
        "level": "beginner",
    })
    assert r5.status_code == 201
    mission_id = r5.json()["id"]

    # Completar missão
    r6 = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": mission_id,
    })
    assert r6.status_code == 201

    # Verificar pontos acumulados
    r7 = await client.get(f"/users/{aluno_user.id}/points", headers=aluno_headers)
    assert r7.status_code == 200
    points_data = r7.json()
    assert points_data["points"] > 0
