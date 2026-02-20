"""Testes do endpoint de health check."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_ok(client: AsyncClient):
    r = await client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"


@pytest.mark.asyncio
async def test_health_db(client: AsyncClient):
    r = await client.get("/health/db")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] in ("ok", "error")
