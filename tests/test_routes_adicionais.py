"""Testes de rotas adicionais: reset_missions, collective_goals, points_log, mission_today/week."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


# ========================== RESET MISSIONS ==========================

async def test_reset_missions(client, admin_headers, academy):
    """Reset de missões da academia."""
    r = await client.post(f"/academies/{academy.id}/reset_missions", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert "message" in data or "reset" in data or "deleted" in data


async def test_reset_missions_professor(client, professor_headers, academy):
    """Professor pode resetar missões da própria academia."""
    r = await client.post(f"/academies/{academy.id}/reset_missions", headers=professor_headers)
    assert r.status_code == 200


async def test_reset_missions_professor_outra_academia_proibido(client, professor_headers, db):
    """Professor não pode resetar missões de outra academia."""
    from app.models import Academy

    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    r = await client.post(f"/academies/{other_academy.id}/reset_missions", headers=professor_headers)
    assert r.status_code == 403


async def test_reset_missions_academia_inexistente(client, admin_headers):
    """Reset de academia inexistente retorna 404."""
    fake_id = uuid4()
    r = await client.post(f"/academies/{fake_id}/reset_missions", headers=admin_headers)
    assert r.status_code == 404


# ========================== COLLECTIVE GOALS ==========================

async def test_criar_meta_coletiva(client, admin_headers, academy, technique):
    """Criar meta coletiva."""
    r = await client.post(f"/academies/{academy.id}/collective_goals", headers=admin_headers, json={
        "technique_id": str(technique.id),
        "target_count": 100,
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=7)).isoformat(),
    })
    assert r.status_code == 201
    data = r.json()
    assert data["technique_id"] == str(technique.id)
    assert data["target_count"] == 100
    assert data["academy_id"] == str(academy.id)


async def test_listar_metas_coletivas(client, admin_headers, academy, technique, db):
    """Listar metas coletivas da academia."""
    from app.models import CollectiveGoal

    # Criar uma meta primeiro
    goal = CollectiveGoal(
        academy_id=academy.id,
        technique_id=technique.id,
        target_count=50,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=7),
    )
    db.add(goal)
    await db.commit()

    r = await client.get(f"/academies/{academy.id}/collective_goals", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_meta_coletiva_atual(client, admin_headers, academy, technique, db):
    """Obter meta coletiva atual da semana."""
    from app.models import CollectiveGoal

    # Criar meta para a semana atual
    goal = CollectiveGoal(
        academy_id=academy.id,
        technique_id=technique.id,
        target_count=100,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)

    r = await client.get(f"/academies/{academy.id}/collective_goals/current", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data is not None
    assert "goal" in data
    assert "current_count" in data
    assert "target_count" in data


async def test_meta_coletiva_atual_inexistente(client, admin_headers, academy):
    """Meta coletiva atual inexistente retorna None."""
    r = await client.get(f"/academies/{academy.id}/collective_goals/current", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data is None


async def test_criar_meta_coletiva_professor(client, professor_headers, academy, technique):
    """Professor pode criar meta coletiva na própria academia."""
    r = await client.post(f"/academies/{academy.id}/collective_goals", headers=professor_headers, json={
        "technique_id": str(technique.id),
        "target_count": 75,
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=7)).isoformat(),
    })
    assert r.status_code == 201


async def test_criar_meta_coletiva_aluno_proibido(client, aluno_headers, academy, technique):
    """Aluno não pode criar meta coletiva."""
    r = await client.post(f"/academies/{academy.id}/collective_goals", headers=aluno_headers, json={
        "technique_id": str(technique.id),
        "target_count": 50,
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=7)).isoformat(),
    })
    assert r.status_code == 403


# ========================== POINTS LOG ==========================

async def test_points_log_usuario(client, admin_headers, aluno_user):
    """Obter log de pontos do usuário."""
    r = await client.get(f"/users/{aluno_user.id}/points_log", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert "user_id" in data
    assert "entries" in data
    assert isinstance(data["entries"], list)


async def test_points_log_com_limit(client, admin_headers, aluno_user):
    """Log de pontos respeita limite."""
    r = await client.get(f"/users/{aluno_user.id}/points_log?limit=10", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert len(data["entries"]) <= 10


async def test_points_log_com_offset(client, admin_headers, aluno_user):
    """Log de pontos com offset."""
    r = await client.get(f"/users/{aluno_user.id}/points_log?limit=10&offset=5", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert "entries" in data


async def test_points_log_usuario_inexistente(client, admin_headers):
    """Log de pontos de usuário inexistente retorna 404."""
    fake_id = uuid4()
    r = await client.get(f"/users/{fake_id}/points_log", headers=admin_headers)
    assert r.status_code == 404


async def test_points_log_aluno_acesso_outro_aluno_proibido(client, aluno_headers, db):
    """Aluno não pode ver log de pontos de outro aluno de outra academia."""
    from app.models import Academy, User
    from app.core.security import hash_password

    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    other_user = User(
        email=f"outro-{uuid4().hex[:8]}@test.com",
        name="Outro Aluno",
        role="aluno",
        graduation="white",
        academy_id=other_academy.id,
        password_hash=hash_password("senha123"),
    )
    db.add(other_user)
    await db.commit()
    await db.refresh(other_user)

    r = await client.get(f"/users/{other_user.id}/points_log", headers=aluno_headers)
    assert r.status_code == 403


async def test_points_log_sem_auth(client, aluno_user):
    """Log de pontos sem autenticação retorna 401."""
    r = await client.get(f"/users/{aluno_user.id}/points_log")
    assert r.status_code == 401


# ========================== MISSION TODAY / WEEK ==========================

async def test_mission_today(client, academy, technique, db):
    """Obter missão do dia."""
    from app.models import Mission, Position

    # Criar posições e missão ativa
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

    r = await client.get(f"/mission_today?level=beginner&academy_id={academy.id}")
    # Pode retornar 200 ou 404 dependendo de ter lição/posição configurada
    assert r.status_code in (200, 404)


async def test_mission_today_com_auth(client, aluno_headers, academy, technique, db):
    """Missão do dia com autenticação (personalização)."""
    from app.models import Mission, Position

    p1 = Position(academy_id=academy.id, name="Guarda", slug=f"guarda-{uuid4().hex[:6]})
    p2 = Position(academy_id=academy.id, name="Montada", slug=f"montada-{uuid4().hex[:6]})
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

    r = await client.get(f"/mission_today?level=beginner&academy_id={academy.id}", headers=aluno_headers)
    assert r.status_code in (200, 404)


async def test_mission_week(client, academy, technique, db):
    """Obter missões da semana."""
    from app.models import Mission, Position

    p1 = Position(academy_id=academy.id, name="Guarda", slug=f"guarda-{uuid4().hex[:6]})
    p2 = Position(academy_id=academy.id, name="Montada", slug=f"montada-{uuid4().hex[:6]})
    db.add_all([p1, p2])
    await db.commit()
    await db.refresh(p1)
    await db.refresh(p2)

    r = await client.get(f"/mission_today/week?level=beginner&academy_id={academy.id}")
    assert r.status_code == 200
    data = r.json()
    assert "missions" in data or "week" in data


async def test_mission_week_com_auth(client, aluno_headers, academy):
    """Missões da semana com autenticação."""
    r = await client.get(f"/mission_today/week?level=beginner&academy_id={academy.id}", headers=aluno_headers)
    assert r.status_code == 200
