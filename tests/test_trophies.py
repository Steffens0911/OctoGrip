"""Testes de CRUD de troféus."""
from datetime import date, datetime, timedelta, timezone
from unittest.mock import MagicMock
from uuid import uuid4

import pytest


def _mock_execution(opponent_id, graduation: str, confirmed_day: int, eid=None):
    e = MagicMock()
    e.id = eid or uuid4()
    e.opponent_id = opponent_id
    opp = MagicMock()
    opp.graduation = graduation
    e.opponent = opp
    e.confirmed_at = datetime(2026, 1, confirmed_day, 12, 0, tzinfo=timezone.utc)
    return e


def test_compute_counts_legacy_bronze_apenas_brancos_distintos():
    """Sem limite: bronze = número de faixas brancas distintas."""
    from app.services.trophy_service import _compute_counts_from_executions

    a, b = uuid4(), uuid4()
    executions = [
        _mock_execution(a, "white", 1),
        _mock_execution(b, "white", 2),
        _mock_execution(a, "white", 3),
    ]
    c = _compute_counts_from_executions(executions, None)
    assert c["gold_count"] == 0
    assert c["silver_count"] == 0
    assert c["bronze_count"] == 2


def test_compute_counts_limite_por_adversario_preta_tres_exec_conta_so_duas():
    """Com limite 2: no máximo 2 ouros no mesmo opponent_id."""
    from app.services.trophy_service import _compute_counts_from_executions

    oid = uuid4()
    executions = [
        _mock_execution(oid, "black", 1),
        _mock_execution(oid, "black", 2),
        _mock_execution(oid, "black", 3),
    ]
    c = _compute_counts_from_executions(executions, 2)
    assert c["gold_count"] == 2
    assert c["silver_count"] == 0
    assert c["bronze_count"] == 0


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
    assert data.get("min_reward_level_to_unlock") == 0


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


async def test_criar_trofeu_max_count_per_opponent(client, admin_headers, academy, technique):
    """Criar troféu com limite de execuções contáveis por adversário."""
    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Troféu Limite Parceiro",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 10,
        "max_count_per_opponent": 2,
    })
    assert r.status_code == 201
    data = r.json()
    assert data["max_count_per_opponent"] == 2


async def test_criar_trofeu_max_count_per_opponent_invalido(client, admin_headers, academy, technique):
    """max_count_per_opponent < 1 é rejeitado."""
    r = await client.post("/trophies", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "technique_id": str(technique.id),
        "name": "Troféu Inválido",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=30)).isoformat(),
        "target_count": 10,
        "max_count_per_opponent": 0,
    })
    assert r.status_code == 422


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
    assert r.status_code == 422


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


async def test_galeria_trofeu_desbloqueio_por_nivel(client, aluno_headers, aluno_user, academy, technique, db):
    """Troféu com nível mínimo alto fica trancado até o usuário atingir reward_level."""
    from app.models import Trophy

    tr = Trophy(
        academy_id=academy.id,
        technique_id=technique.id,
        name="Troféu Nível 5",
        start_date=date.today(),
        end_date=date.today() + timedelta(days=30),
        target_count=1,
        min_reward_level_to_unlock=5,
    )
    db.add(tr)
    await db.commit()
    await db.refresh(tr)

    r = await client.get(f"/trophies/user/{aluno_user.id}", headers=aluno_headers)
    assert r.status_code == 200
    item = next((t for t in r.json() if t["trophy_id"] == str(tr.id)), None)
    assert item is not None
    assert item.get("max_count_per_opponent") is None
    assert item["min_reward_level_to_unlock"] == 5
    assert item["unlocked"] is False

    aluno_user.reward_level = 5
    await db.commit()

    r2 = await client.get(f"/trophies/user/{aluno_user.id}", headers=aluno_headers)
    assert r2.status_code == 200
    item2 = next((t for t in r2.json() if t["trophy_id"] == str(tr.id)), None)
    assert item2 is not None
    assert item2["unlocked"] is True


async def test_galeria_trofeus_usuario_inexistente(client, admin_headers):
    """Galeria de troféus de usuário inexistente retorna 404."""
    fake_user_id = uuid4()
    r = await client.get(f"/trophies/user/{fake_user_id}", headers=admin_headers)
    assert r.status_code == 404


async def test_galeria_trofeus_aluno_acesso_outro_aluno_proibido(client, aluno_headers, db):
    """Aluno não pode ver galeria de outro aluno de outra academia."""
    from app.models import Academy, User
    from app.core.security import hash_password_sync

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
        password_hash=hash_password_sync("senha123"),
    )
    db.add(other_user)
    await db.commit()
    await db.refresh(other_user)

    r = await client.get(f"/trophies/user/{other_user.id}", headers=aluno_headers)
    assert r.status_code == 403


async def test_galeria_trofeus_admin_pode_ver_qualquer_usuario(client, admin_headers, db, academy):
    """Admin pode ver galeria de qualquer usuário."""
    from app.models import User
    from app.core.security import hash_password_sync

    other_user = User(
        email=f"outro-{uuid4().hex[:8]}@test.com",
        name="Outro Usuário",
        role="aluno",
        graduation="white",
        academy_id=academy.id,
        password_hash=hash_password_sync("senha123"),
    )
    db.add(other_user)
    await db.commit()
    await db.refresh(other_user)

    r = await client.get(f"/trophies/user/{other_user.id}", headers=admin_headers)
    assert r.status_code == 200


async def test_galeria_privada_retorna_403(client, aluno_headers, admin_headers, db, academy, trophy):
    """Quando o dono da galeria tem gallery_visible=False, outro usuário recebe 403."""
    from app.models import User
    from app.core.security import create_access_token, hash_password_sync

    other_user = User(
        email=f"outro-{uuid4().hex[:8]}@test.com",
        name="Outro Aluno",
        role="aluno",
        graduation="white",
        academy_id=academy.id,
        password_hash=hash_password_sync("senha123"),
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
