"""Testes de técnicas (CRUD). Posições foram removidas do domínio/API."""
from uuid import uuid4


async def test_rota_posicoes_nao_existe(client, admin_headers, academy):
    """Endpoints /positions não estão registados."""
    r = await client.get(f"/positions?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 404


# ========================== TÉCNICAS ==========================


async def test_listar_tecnicas(client, admin_headers, academy, technique):
    r = await client.get(f"/techniques?academy_id={academy.id}", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1


async def test_listar_tecnicas_sem_academy_id(client, admin_headers):
    """Admin sem academy_id na query recebe erro de domínio (400)."""
    r = await client.get("/techniques", headers=admin_headers)
    assert r.status_code == 400


async def test_listar_tecnicas_sem_auth(client, academy):
    r = await client.get(f"/techniques?academy_id={academy.id}")
    assert r.status_code == 401


async def test_criar_tecnica(client, admin_headers, academy):
    r = await client.post(
        "/techniques",
        headers=admin_headers,
        json={
            "academy_id": str(academy.id),
            "name": f"Técnica {uuid4().hex[:4]}",
        },
    )
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


async def test_excluir_tecnica(client, admin_headers, academy, db):
    from app.models import Technique

    t = Technique(
        academy_id=academy.id,
        name=f"Temp {uuid4().hex[:4]}",
        slug=f"temp-{uuid4().hex[:6]}",
    )
    db.add(t)
    await db.commit()
    await db.refresh(t)

    r = await client.delete(
        f"/techniques/{t.id}?academy_id={academy.id}",
        headers=admin_headers,
    )
    assert r.status_code == 204
