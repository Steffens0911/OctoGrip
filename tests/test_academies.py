"""Testes de academias (CRUD)."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_academies_empty(client: AsyncClient):
    r = await client.get("/academies")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.asyncio
async def test_create_academy(client: AsyncClient):
    r = await client.post("/academies", json={"name": "Test Academy"})
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Test Academy"
    assert "id" in data


@pytest.mark.asyncio
async def test_get_academy_not_found(client: AsyncClient):
    r = await client.get("/academies/00000000-0000-0000-0000-000000000000")
    assert r.status_code == 404
