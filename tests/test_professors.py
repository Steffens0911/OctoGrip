"""Testes de CRUD de professores."""
import pytest
from uuid import uuid4


@pytest.fixture
async def professor_user_2(db, academy):
    """Cria um segundo professor para testes."""
    from app.models import User
    from app.core.security import hash_password_sync

    user = User(
        email=f"prof2-{uuid4().hex[:8]}@test.com",
        name="Professor 2",
        role="professor",
        graduation="black",
        academy_id=academy.id,
        password_hash=hash_password_sync("prof1234"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
async def professor_record(db, academy):
    """Cria um registro de Professor para testes."""
    from app.models import Professor

    prof = Professor(
        name="Professor Teste",
        email=f"prof-record-{uuid4().hex[:8]}@test.com",
        academy_id=academy.id,
    )
    db.add(prof)
    await db.commit()
    await db.refresh(prof)
    return prof


async def test_listar_professores_admin(client, admin_headers, academy, professor_record):
    """Admin pode listar todos os professores."""
    r = await client.get("/professors", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_listar_professores_com_filtro_academia(client, admin_headers, academy, professor_record, db):
    """Listar professores filtrados por academia."""
    from app.models import Academy, Professor

    # Criar outra academia e professor
    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    other_prof = Professor(
        name="Prof Outra",
        email=f"outro-{uuid4().hex[:8]}@test.com",
        academy_id=other_academy.id,
    )
    db.add(other_prof)
    await db.commit()

    # Listar apenas professores da primeira academia
    r = await client.get(f"/professors?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert all(p["academy_id"] == str(academy.id) for p in data)


async def test_listar_professores_professor_ve_apenas_propria_academia(client, professor_headers, academy, professor_record, db):
    """Professor só vê professores da própria academia."""
    from app.models import Academy, Professor

    # Criar outra academia e professor
    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    other_prof = Professor(
        name="Prof Outra",
        email=f"outro-{uuid4().hex[:8]}@test.com",
        academy_id=other_academy.id,
    )
    db.add(other_prof)
    await db.commit()

    # Professor deve ver apenas professores da sua academia
    r = await client.get("/professors", headers=professor_headers)
    assert r.status_code == 200
    data = r.json()
    assert all(p["academy_id"] == str(academy.id) for p in data)


async def test_listar_professores_sem_auth(client):
    """Listar professores sem autenticação retorna 401."""
    r = await client.get("/professors")
    assert r.status_code == 401


async def test_obter_professor_por_id(client, admin_headers, professor_record):
    """Obter professor por ID."""
    r = await client.get(f"/professors/{professor_record.id}", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["id"] == str(professor_record.id)
    assert data["name"] == professor_record.name
    assert data["email"] == professor_record.email


async def test_obter_professor_nao_encontrado(client, admin_headers):
    """Obter professor inexistente retorna 404."""
    fake_id = uuid4()
    r = await client.get(f"/professors/{fake_id}", headers=admin_headers)
    assert r.status_code == 404


async def test_obter_professor_professor_acesso_outra_academia_proibido(client, professor_headers, db):
    """Professor não pode acessar professor de outra academia."""
    from app.models import Academy, Professor

    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    other_prof = Professor(
        name="Prof Outra",
        email=f"outro-{uuid4().hex[:8]}@test.com",
        academy_id=other_academy.id,
    )
    db.add(other_prof)
    await db.commit()
    await db.refresh(other_prof)

    r = await client.get(f"/professors/{other_prof.id}", headers=professor_headers)
    assert r.status_code == 403


async def test_criar_professor_admin(client, admin_headers, academy):
    """Admin pode criar professor."""
    r = await client.post("/professors", headers=admin_headers, json={
        "name": "Novo Professor",
        "email": f"novo-{uuid4().hex[:8]}@test.com",
        "academy_id": str(academy.id),
    })
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Novo Professor"
    assert data["academy_id"] == str(academy.id)


async def test_criar_professor_professor_forca_propria_academia(client, professor_headers, academy):
    """Professor cria professor na própria academia (academy_id ignorado)."""
    r = await client.post("/professors", headers=professor_headers, json={
        "name": "Novo Professor",
        "email": f"novo-{uuid4().hex[:8]}@test.com",
        "academy_id": str(uuid4()),  # Tentar outra academia
    })
    assert r.status_code == 201
    data = r.json()
    # Deve ser criado na academia do professor, não na fornecida
    assert data["academy_id"] == str(academy.id)


async def test_criar_professor_email_duplicado(client, admin_headers, professor_record):
    """Criar professor com email duplicado retorna 409."""
    r = await client.post("/professors", headers=admin_headers, json={
        "name": "Duplicado",
        "email": professor_record.email,  # Email já existente
    })
    assert r.status_code == 409


async def test_criar_professor_sem_auth(client):
    """Criar professor sem autenticação retorna 401."""
    r = await client.post("/professors", json={
        "name": "Teste",
        "email": f"teste-{uuid4().hex[:8]}@test.com",
    })
    assert r.status_code == 401


async def test_atualizar_professor(client, admin_headers, professor_record):
    """Atualizar professor."""
    r = await client.patch(f"/professors/{professor_record.id}", headers=admin_headers, json={
        "name": "Nome Atualizado",
        "email": f"atualizado-{uuid4().hex[:8]}@test.com",
    })
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Nome Atualizado"


async def test_atualizar_professor_parcial(client, admin_headers, professor_record):
    """Atualizar apenas nome do professor."""
    original_email = professor_record.email
    r = await client.patch(f"/professors/{professor_record.id}", headers=admin_headers, json={
        "name": "Só Nome",
    })
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Só Nome"
    assert data["email"] == original_email


async def test_atualizar_professor_nao_encontrado(client, admin_headers):
    """Atualizar professor inexistente retorna 404."""
    fake_id = uuid4()
    r = await client.patch(f"/professors/{fake_id}", headers=admin_headers, json={
        "name": "Teste",
    })
    assert r.status_code == 404


async def test_atualizar_professor_professor_nao_pode_mudar_academia(client, professor_headers, professor_record):
    """Professor não pode alterar academy_id."""
    from app.models import Academy
    from uuid import uuid4

    # Tentar atualizar academy_id (deve ser ignorado)
    r = await client.patch(f"/professors/{professor_record.id}", headers=professor_headers, json={
        "name": "Atualizado",
        "academy_id": str(uuid4()),  # Tentar mudar academia
    })
    assert r.status_code == 200
    data = r.json()
    # academy_id deve permanecer o mesmo
    assert data["academy_id"] == str(professor_record.academy_id)


async def test_atualizar_professor_professor_acesso_outra_academia_proibido(client, professor_headers, db):
    """Professor não pode atualizar professor de outra academia."""
    from app.models import Academy, Professor

    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    other_prof = Professor(
        name="Prof Outra",
        email=f"outro-{uuid4().hex[:8]}@test.com",
        academy_id=other_academy.id,
    )
    db.add(other_prof)
    await db.commit()
    await db.refresh(other_prof)

    r = await client.patch(f"/professors/{other_prof.id}", headers=professor_headers, json={
        "name": "Tentativa",
    })
    assert r.status_code == 403


async def test_excluir_professor(client, admin_headers, db, academy):
    """Excluir professor."""
    from app.models import Professor

    prof = Professor(
        name="Para Deletar",
        email=f"deletar-{uuid4().hex[:8]}@test.com",
        academy_id=academy.id,
    )
    db.add(prof)
    await db.commit()
    await db.refresh(prof)

    r = await client.delete(f"/professors/{prof.id}", headers=admin_headers)
    assert r.status_code == 204


async def test_excluir_professor_nao_encontrado(client, admin_headers):
    """Excluir professor inexistente retorna 404."""
    fake_id = uuid4()
    r = await client.delete(f"/professors/{fake_id}", headers=admin_headers)
    assert r.status_code == 404


async def test_excluir_professor_sem_auth(client, professor_record):
    """Excluir professor sem autenticação retorna 401."""
    r = await client.delete(f"/professors/{professor_record.id}")
    assert r.status_code == 401
