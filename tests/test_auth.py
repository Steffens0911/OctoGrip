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


async def test_patch_me_gallery_visible(client, admin_headers, admin_user):
    """PATCH /auth/me atualiza gallery_visible do usuário autenticado."""
    r = await client.patch("/auth/me", headers=admin_headers, json={"gallery_visible": False})
    assert r.status_code == 200
    data = r.json()
    assert data["gallery_visible"] is False
    r2 = await client.get("/auth/me", headers=admin_headers)
    assert r2.json()["gallery_visible"] is False
    r3 = await client.patch("/auth/me", headers=admin_headers, json={"gallery_visible": True})
    assert r3.json()["gallery_visible"] is True
