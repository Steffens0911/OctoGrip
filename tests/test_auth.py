"""Testes de autenticação (login + /auth/me)."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_login_invalid_credentials(client: AsyncClient):
    r = await client.post("/auth/login", json={
        "email": "naoexiste@test.com",
        "password": "wrong",
    })
    assert r.status_code == 401
    assert "inválidos" in r.json()["detail"].lower()


@pytest.mark.asyncio
async def test_me_without_token(client: AsyncClient):
    r = await client.get("/auth/me")
    assert r.status_code in (401, 403)
