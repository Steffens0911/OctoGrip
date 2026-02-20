"""Testes de CRUD de posições e técnicas."""
import pytest
from uuid import uuid4


# ========================== POSIÇÕES ==========================

async def test_listar_posicoes(client, admin_headers, academy, position_pair):
    r = await client.get(f"/positions?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 2


async def test_listar_posicoes_sem_academy_id(client, admin_headers):
    r = await client.get("/positions", headers=admin_headers)
    assert r.status_code == 400


async def test_criar_posicao(client, admin_headers, academy):
    r = await client.post("/positions", headers=admin_headers, json={
        "academy_id": str(academy.id),
        "name": f"Posição {uuid4().hex[:4]}",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["academy_id"] == str(academy.id)
    assert data["slug"] is not None


async def test_obter_posicao_por_id(client, admin_headers, academy, position_pair):
    p1, _ = position_pair
    r = await client.get(f"/positions/{p1.id}?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 200
    assert r.json()["id"] == str(p1.id)


async def test_atualizar_posicao(client, admin_headers, academy, position_pair):
    p1, _ = position_pair
    r = await client.put(f"/positions/{p1.id}?academy_id={academy.id}", headers=admin_headers, json={
        "name": "Guarda Atualizada",
    })
    assert r.status_code == 200
    assert r.json()["name"] == "Guarda Atualizada"


async def test_excluir_posicao_sem_tecnicas(client, admin_headers, academy, db):
    from app.models import Position

    p = Position(academy_id=academy.id, name=f"Temp {uuid4().hex[:4]}", slug=f"temp-{uuid4().hex[:6]}")
    db.add(p)
    await db.commit()
    await db.refresh(p)

    r = await client.delete(f"/positions/{p.id}?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 204


# ========================== TÉCNICAS ==========================

async def test_listar_tecnicas(client, admin_headers, academy, technique):
    r = await client.get(f"/techniques?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1


async def test_listar_tecnicas_sem_academy_id(client):
    r = await client.get("/techniques")
    assert r.status_code == 400


async def test_criar_tecnica(client, admin_headers, academy, position_pair):
    p1, p2 = position_pair
    r = await client.post("/techniques", json={
        "academy_id": str(academy.id),
        "name": f"Técnica {uuid4().hex[:4]}",
        "from_position_id": str(p1.id),
        "to_position_id": str(p2.id),
    })
    assert r.status_code == 201
    data = r.json()
    assert data["academy_id"] == str(academy.id)


async def test_obter_tecnica_por_id(client, admin_headers, academy, technique):
    r = await client.get(
        f"/techniques/{technique.id}?academy_id={academy.id}",
        headers=admin_headers,
    )
    assert r.status_code == 200
    assert r.json()["id"] == str(technique.id)


async def test_atualizar_tecnica(client, admin_headers, academy, technique):
    r = await client.put(
        f"/techniques/{technique.id}?academy_id={academy.id}",
        headers=admin_headers,
        json={"name": "Técnica Renomeada"},
    )
    assert r.status_code == 200
    assert r.json()["name"] == "Técnica Renomeada"


async def test_excluir_tecnica(client, admin_headers, academy, db, position_pair):
    from app.models import Technique

    p1, p2 = position_pair
    t = Technique(
        academy_id=academy.id,
        name=f"Temp {uuid4().hex[:4]}",
        slug=f"temp-{uuid4().hex[:6]}",
        from_position_id=p1.id,
        to_position_id=p2.id,
    )
    db.add(t)
    await db.commit()
    await db.refresh(t)

    r = await client.delete(
        f"/techniques/{t.id}?academy_id={academy.id}",
        headers=admin_headers,
    )
    assert r.status_code == 204
