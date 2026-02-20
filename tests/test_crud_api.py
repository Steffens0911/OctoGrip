"""Testes de endpoints CRUD (sem banco real - usa SQLite in-memory)."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_users_empty(client: AsyncClient):
    r = await client.get("/users")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.asyncio
async def test_get_user_not_found(client: AsyncClient):
    r = await client.get("/users/00000000-0000-0000-0000-000000000001")
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_list_missions_empty(client: AsyncClient):
    r = await client.get("/missions")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.asyncio
async def test_metrics_usage(client: AsyncClient):
    r = await client.get("/metrics/usage")
    assert r.status_code == 200
    data = r.json()
    assert "total_completions" in data


@pytest.mark.asyncio
async def test_home_page(client: AsyncClient):
    r = await client.get("/")
    assert r.status_code == 200
    assert "JJB API" in r.text
