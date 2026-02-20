"""Testes de autenticação: login, JWT, /me."""
import pytest


async def test_login_sucesso(client, admin_user):
    r = await client.post("/auth/login", json={
        "email": admin_user.email,
        "password": "admin123",
    })
    assert r.status_code == 200
    data = r.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


async def test_login_email_invalido(client):
    r = await client.post("/auth/login", json={
        "email": "naoexiste@test.com",
        "password": "qualquer",
    })
    assert r.status_code == 401


async def test_login_senha_errada(client, admin_user):
    r = await client.post("/auth/login", json={
        "email": admin_user.email,
        "password": "senhaerrada",
    })
    assert r.status_code == 401


async def test_me_sem_token(client):
    r = await client.get("/auth/me")
    assert r.status_code == 401


async def test_me_com_token(client, admin_user, admin_headers):
    r = await client.get("/auth/me", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["email"] == admin_user.email
    assert data["role"] == "administrador"


async def test_me_token_invalido(client):
    r = await client.get("/auth/me", headers={"Authorization": "Bearer tokeninvalido"})
    assert r.status_code == 401
