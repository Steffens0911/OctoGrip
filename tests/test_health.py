"""Testes do health check."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient):
    r = await client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"


@pytest.mark.asyncio
async def test_home_page(client: AsyncClient):
    r = await client.get("/")
    assert r.status_code == 200
    assert "JJB API" in r.text
