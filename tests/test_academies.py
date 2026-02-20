"""Testes de CRUD de academias."""
import pytest


async def test_listar_academias(client, admin_headers, academy):
    r = await client.get("/academies", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_criar_academia(client, admin_headers):
    r = await client.post("/academies", headers=admin_headers, json={
        "name": "Nova Academia Teste",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Nova Academia Teste"
    assert data["slug"] is not None


async def test_obter_academia_por_id(client, admin_headers, academy):
    r = await client.get(f"/academies/{academy.id}", headers=admin_headers)
    assert r.status_code == 200
    assert r.json()["id"] == str(academy.id)


async def test_atualizar_academia(client, admin_headers, academy):
    r = await client.patch(f"/academies/{academy.id}", headers=admin_headers, json={
        "name": "Nome Atualizado",
        "weekly_theme": "Passagem de guarda",
    })
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Nome Atualizado"


async def test_excluir_academia(client, admin_headers, db):
    from app.models import Academy
    from uuid import uuid4

    a = Academy(name="Para Deletar", slug=f"del-{uuid4().hex[:6]}")
    db.add(a)
    await db.commit()
    await db.refresh(a)

    r = await client.delete(f"/academies/{a.id}", headers=admin_headers)
    assert r.status_code == 204


async def test_academia_nao_encontrada(client, admin_headers):
    from uuid import uuid4
    fake_id = uuid4()
    r = await client.get(f"/academies/{fake_id}", headers=admin_headers)
    assert r.status_code == 404


async def test_ranking_academia_vazio(client, admin_headers, academy):
    r = await client.get(f"/academies/{academy.id}/ranking", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["entries"] == []


async def test_dificuldades_academia_vazio(client, admin_headers, academy):
    r = await client.get(f"/academies/{academy.id}/difficulties", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["entries"] == []


async def test_relatorio_semanal_academia(client, admin_headers, academy):
    r = await client.get(f"/academies/{academy.id}/report/weekly", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert "week_start" in data
    assert "completions_count" in data


async def test_relatorio_semanal_csv(client, admin_headers, academy):
    r = await client.get(f"/academies/{academy.id}/report/weekly/csv", headers=admin_headers)
    assert r.status_code == 200
    assert "rank;user_id;name;completions_count" in r.text


async def test_professor_ve_apenas_propria_academia(client, professor_headers, academy):
    r = await client.get("/academies", headers=professor_headers)
    assert r.status_code == 200
    data = r.json()
    assert all(a["id"] == str(academy.id) for a in data)


async def test_professor_nao_pode_criar_academia(client, professor_headers):
    r = await client.post("/academies", headers=professor_headers, json={
        "name": "Proibido",
    })
    assert r.status_code == 403
