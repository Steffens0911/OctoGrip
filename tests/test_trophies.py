"""Testes de CRUD de troféus."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


@pytest.fixture
async def trophy(db, academy, technique):
    """Cria um troféu para testes."""
    from app.models import Trophy

    trophy = Trophy(
        academy_id=academy.id,
        technique_id=technique.id,
        name="Troféu Teste",
        start_date=date.today(),
        end_date=date.today() + timedelta(days=30),
        target_count=10,
    )
    db.add(trophy)
    await db.commit()
    await db.refresh(trophy)
    return trophy


async def test_criar_trofeu_admin(client, admin_headers, academy, technique):
    """Admin pode criar troféu."""
    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Novo Troféu",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 15,
    })
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Novo Troféu"
    assert data["academy_id"] == str(academy.id)
    assert data["technique_id"] == str(technique.id)
    assert data["target_count"] == 15


async def test_criar_trofeu_professor(client, professor_headers, academy, technique):
    """Professor pode criar troféu na própria academia."""
    r = await client.post("/trophies", headers=professor_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Troféu Professor",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 20,
    })
    assert r.status_code == 201


async def test_criar_trofeu_aluno_proibido(client, aluno_headers, academy, technique):
    """Aluno não pode criar troféu."""
    r = await client.post("/trophies", headers=aluno_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Troféu Aluno",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 10,
    })
    assert r.status_code == 403


async def test_criar_trofeu_tecnica_outra_academia(client, admin_headers, academy, db):
    """Não pode criar troféu com técnica de outra academia."""
    from app.models import Academy, Technique

    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    other_technique = Technique(
        academy_id=other_academy.id,
        name="Técnica Outra",
        slug=f"tecnica-{uuid4().hex[:6]}",
    )
    db.add(other_technique)
    await db.commit()
    await db.refresh(other_technique)

    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(other_technique.id),  # Técnica de outra academia
        "name": "Troféu Inválido",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 10,
    })
    assert r.status_code == 400


async def test_criar_trofeu_data_invalida(client, admin_headers, academy, technique):
    """Não pode criar troféu com end_date < start_date."""
    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Troféu Inválido",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() - timedelta(days=1)).isoformat(),  # Data anterior
        "target_count": 10,
    })
    assert r.status_code == 400


async def test_criar_trofeu_academia_inexistente(client, admin_headers, technique):
    """Não pode criar troféu com academia inexistente."""
    fake_academy_id = uuid4()
    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(fake_academy_id),
        "technique_id": str(technique.id),
        "name": "Troféu Inválido",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 10,
    })
    assert r.status_code == 404


async def test_criar_trofeu_tecnica_inexistente(client, admin_headers, academy):
    """Não pode criar troféu com técnica inexistente."""
    fake_technique_id = uuid4()
    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(fake_technique_id),
        "name": "Troféu Inválido",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 10,
    })
    assert r.status_code == 404


async def test_listar_trofeus_por_academia(client, admin_headers, academy, trophy):
    """Listar troféus por academia."""
    r = await client.get(f"/trophies?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(t["id"] == str(trophy.id) for t in data)


async def test_listar_trofeus_sem_academy_id(client, admin_headers):
    """Listar troféus sem academy_id retorna 422."""
    r = await client.get("/trophies", headers=admin_headers)
    assert r.status_code == 422


async def test_listar_trofeus_professor_acesso_outra_academia_proibido(client, professor_headers, db):
    """Professor não pode listar troféus de outra academia."""
    from app.models import Academy

    other_academy = Academy(name="Outra Academia", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    r = await client.get(f"/trophies?academy_id={other_academy.id}", headers=professor_headers)
    assert r.status_code == 403


async def test_listar_trofeus_sem_auth(client, academy):
    """Listar troféus sem autenticação retorna 401."""
    r = await client.get(f"/trophies?academy_id={academy.id}")
    assert r.status_code == 401


async def test_galeria_trofeus_usuario(client, aluno_headers, aluno_user, academy, trophy):
    """Galeria de troféus do usuário."""
    r = await client.get(f"/trophies/user/{aluno_user.id}", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    # Deve incluir o troféu criado
    assert any(t["trophy_id"] == str(trophy.id) for t in data)


async def test_galeria_trofeus_usuario_inexistente(client, admin_headers):
    """Galeria de troféus de usuário inexistente retorna 404."""
    fake_user_id = uuid4()
    r = await client.get(f"/trophies/user/{fake_user_id}", headers=admin_headers)
    assert r.status_code == 404


async def test_galeria_trofeus_aluno_acesso_outro_aluno_proibido(client, aluno_headers, db):
    """Aluno não pode ver galeria de outro aluno de outra academia."""
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

    r = await client.get(f"/trophies/user/{other_user.id}", headers=aluno_headers)
    assert r.status_code == 403


async def test_galeria_trofeus_admin_pode_ver_qualquer_usuario(client, admin_headers, db, academy):
    """Admin pode ver galeria de qualquer usuário."""
    from app.models import User
    from app.core.security import hash_password

    other_user = User(
        email=f"outro-{uuid4().hex[:8]}@test.com",
        name="Outro Usuário",
        role="aluno",
        graduation="white",
        academy_id=academy.id,
        password_hash=hash_password("senha123"),
    )
    db.add(other_user)
    await db.commit()
    await db.refresh(other_user)

    r = await client.get(f"/trophies/user/{other_user.id}", headers=admin_headers)
    assert r.status_code == 200


async def test_galeria_privada_retorna_403(client, aluno_headers, admin_headers, db, academy, trophy):
    """Quando o dono da galeria tem gallery_visible=False, outro usuário recebe 403."""
    from app.models import User
    from app.core.security import hash_password, create_access_token

    other_user = User(
        email=f"outro-{uuid4().hex[:8]}@test.com",
        name="Outro Aluno",
        role="aluno",
        graduation="white",
        academy_id=academy.id,
        password_hash=hash_password("senha123"),
        gallery_visible=False,
    )
    db.add(other_user)
    await db.commit()
    await db.refresh(other_user)

    r = await client.get(f"/trophies/user/{other_user.id}", headers=aluno_headers)
    assert r.status_code == 403
    detail = r.json().get("detail") or ""
    if isinstance(detail, list):
        detail = " ".join(str(x) for x in detail)
    assert "privada" in str(detail).lower()

    r_admin = await client.get(f"/trophies/user/{other_user.id}", headers=admin_headers)
    assert r_admin.status_code == 403
