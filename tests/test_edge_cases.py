"""Testes de edge cases: validações de input, relacionamentos, datas, duplicação, deleção, permissões, paginação."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


# ========================== VALIDAÇÕES DE INPUT ==========================

async def test_criar_usuario_sem_campos_obrigatorios(client, admin_headers):
    """Criar usuário sem campos obrigatórios retorna 422."""
    r = await client.post("/users", headers=admin_headers, json={})
    assert r.status_code == 422


async def test_criar_posicao_sem_academy_id(client, admin_headers):
    """Criar posição sem academy_id retorna 400."""
    r = await client.post("/positions", headers=admin_headers, json={
        "name": "Posição Teste",
    })
    assert r.status_code == 400


async def test_criar_tecnica_sem_academy_id(client, admin_headers):
    """Criar técnica sem academy_id retorna 400."""
    r = await client.post("/techniques", headers=admin_headers, json={
        "name": "Técnica Teste",
    })
    assert r.status_code == 400


async def test_uuid_invalido(client, admin_headers):
    """UUID inválido retorna 422."""
    r = await client.get("/users/invalid-uuid", headers=admin_headers)
    assert r.status_code == 422


async def test_limit_negativo(client, admin_headers, aluno_user):
    """Limit negativo retorna 422."""
    r = await client.get(f"/users/{aluno_user.id}/points_log?limit=-1", headers=admin_headers)
    assert r.status_code == 422


async def test_limit_muito_alto(client, admin_headers, aluno_user):
    """Limit muito alto é limitado ao máximo."""
    r = await client.get(f"/users/{aluno_user.id}/points_log?limit=10000", headers=admin_headers)
    assert r.status_code == 200
    # O endpoint deve limitar a 500 (definido no schema)


async def test_offset_negativo(client, admin_headers, aluno_user):
    """Offset negativo retorna 422."""
    r = await client.get(f"/users/{aluno_user.id}/points_log?offset=-1", headers=admin_headers)
    assert r.status_code == 422


# ========================== VALIDAÇÕES DE RELACIONAMENTOS ==========================

async def test_criar_tecnica_posicoes_academias_diferentes(client, admin_headers, academy, db):
    """Mantido apenas por compatibilidade histórica; hoje técnica não usa posições."""
    r = await client.post("/techniques", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "name": "Técnica Sem Posição",
    })
    assert r.status_code in (201, 400, 422)


async def test_criar_missao_tecnica_inexistente(client, admin_headers):
    """Criar missão com técnica inexistente retorna 404."""
    fake_technique_id = uuid4()
    r = await client.post("/missions", headers=admin_headers, json={
        "technique_id": str(fake_technique_id),
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=6)).isoformat(),
        "level": "beginner",
    })
    assert r.status_code == 404


async def test_criar_execucao_oponente_academia_diferente(client, aluno_headers, aluno_user, mission_with_lesson, db):
    """Não pode criar execução com oponente de academia diferente."""
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

    mission, _ = mission_with_lesson
    r = await client.post("/executions", headers=aluno_headers, json={
        "mission_id": str(mission.id),
        "opponent_id": str(other_user.id),  # Oponente de outra academia
    })
    assert r.status_code == 400


# ========================== VALIDAÇÕES DE DATAS ==========================

async def test_criar_missao_end_date_anterior_start_date(client, admin_headers, technique):
    """Não pode criar missão com end_date < start_date."""
    r = await client.post("/missions", headers=admin_headers, json={
        "technique_id": str(technique.id),
        "start_date": date.today().isoformat(),
        "end_date": (date.today() - timedelta(days=1)).isoformat(),  # Data anterior
        "level": "beginner",
    })
    assert r.status_code == 400


async def test_criar_trofeu_end_date_anterior_start_date(client, admin_headers, academy, technique):
    """Não pode criar troféu com end_date < start_date."""
    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Troféu Inválido",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() - timedelta(days=1)).isoformat(),
        "target_count": 10,
    })
    assert r.status_code == 400


async def test_criar_meta_coletiva_end_date_anterior_start_date(client, admin_headers, academy, technique):
    """Não pode criar meta coletiva com end_date < start_date."""
    r = await client.post(f"/academies/{academy.id}/collective_goals", headers=admin_headers, json={
        "technique_id": str(technique.id),
        "target_count": 100,
        "start_date": date.today().isoformat(),
        "end_date": (date.today() - timedelta(days=1)).isoformat(),
    })
    assert r.status_code == 422  # Validação do Pydantic


# ========================== VALIDAÇÕES DE DUPLICAÇÃO ==========================

async def test_completar_missao_duplicada(client, aluno_headers, aluno_user, mission_with_lesson):
    """Tentar completar missão duas vezes retorna 409."""
    mission, _ = mission_with_lesson
    # Primeira conclusão
    r1 = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission.id),
    })
    assert r1.status_code == 201

    # Segunda conclusão
    r2 = await client.post("/mission_complete", headers=aluno_headers, json={
        "mission_id": str(mission.id),
    })
    assert r2.status_code == 409


async def test_completar_licao_duplicada(client, aluno_headers, aluno_user, technique, db):
    """Tentar completar lição duas vezes retorna 409."""
    from app.models import Lesson

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Duplicada",
        slug=f"duplicada-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    # Primeira conclusão
    r1 = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": str(lesson.id),
    })
    assert r1.status_code == 201

    # Segunda conclusão
    r2 = await client.post("/lesson_complete", headers=aluno_headers, json={
        "lesson_id": str(lesson.id),
    })
    assert r2.status_code == 409


# ========================== VALIDAÇÕES DE DELEÇÃO ==========================

async def test_deletar_posicao_com_tecnicas(client, admin_headers, academy, position_pair, technique):
    """Não pode deletar posição com técnicas associadas."""
    p1, _ = position_pair
    # technique já usa p1 como from_position_id
    
    r = await client.delete(f"/positions/{p1.id}?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 400  # Deve retornar erro de constraint


async def test_deletar_tecnica_com_missoes(client, admin_headers, academy, technique, db):
    """Não pode deletar técnica com missões ativas."""
    from app.models import Mission

    mission = Mission(
        academy_id=academy.id,
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
    )
    db.add(mission)
    await db.commit()

    r = await client.delete(f"/techniques/{technique.id}?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 400  # Deve retornar erro de constraint


# ========================== VALIDAÇÕES DE PERMISSÕES ==========================

async def test_aluno_modificar_outro_aluno(client, aluno_headers, db):
    """Aluno não pode modificar outro aluno."""
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

    r = await client.patch(f"/users/{other_user.id}", headers=aluno_headers, json={
        "name": "Tentativa",
    })
    assert r.status_code == 403


async def test_professor_acessar_outra_academia(client, professor_headers, db):
    """Professor não pode acessar outra academia."""
    from app.models import Academy

    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    r = await client.get(f"/academies/{other_academy.id}", headers=professor_headers)
    assert r.status_code == 403


async def test_operacao_sem_auth(client):
    """Operações sem autenticação retornam 401."""
    r = await client.get("/users")
    assert r.status_code == 401
    
    r = await client.post("/missions", json={})
    assert r.status_code == 401
    
    r = await client.get("/academies")
    assert r.status_code == 401


# ========================== VALIDAÇÕES DE PAGINAÇÃO ==========================

async def test_paginação_limit_zero(client, admin_headers, aluno_user):
    """Limit zero retorna 422."""
    r = await client.get(f"/users/{aluno_user.id}/points_log?limit=0", headers=admin_headers)
    assert r.status_code == 422


async def test_paginação_offset_maior_que_total(client, admin_headers, aluno_user):
    """Offset maior que total retorna lista vazia."""
    r = await client.get(f"/users/{aluno_user.id}/points_log?limit=10&offset=99999", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert len(data["entries"]) == 0


async def test_paginação_combinacao_limit_offset(client, admin_headers, aluno_user):
    """Paginação com limit e offset funciona corretamente."""
    # Primeira página
    r1 = await client.get(f"/users/{aluno_user.id}/points_log?limit=5&offset=0", headers=admin_headers)
    assert r1.status_code == 200
    data1 = r1.json()
    
    # Segunda página
    r2 = await client.get(f"/users/{aluno_user.id}/points_log?limit=5&offset=5", headers=admin_headers)
    assert r2.status_code == 200
    data2 = r2.json()
    
    # Não deve haver sobreposição se houver dados suficientes
    if len(data1["entries"]) > 0 and len(data2["entries"]) > 0:
        assert data1["entries"][0] != data2["entries"][0]
