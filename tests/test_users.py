"""Testes de CRUD de usuários."""
import pytest


async def test_listar_usuarios_admin(client, admin_user, admin_headers):
    r = await client.get("/users", headers=admin_headers)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_listar_usuarios_sem_auth(client):
    r = await client.get("/users")
    assert r.status_code == 401


async def test_criar_usuario_admin(client, admin_headers, academy):
    r = await client.post("/users", headers=admin_headers, json={
        "email": "novo@test.com",
        "name": "Novo Usuário",
        "graduation": "white",
        "role": "aluno",
        "academy_id": str(academy.id),
        "password": "senha123",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["email"] == "novo@test.com"
    assert data["name"] == "Novo Usuário"
    assert data["role"] == "aluno"


async def test_criar_usuario_email_duplicado(client, admin_headers, admin_user):
    r = await client.post("/users", headers=admin_headers, json={
        "email": admin_user.email,
        "name": "Dup",
        "role": "administrador",
    })
    assert r.status_code == 409


async def test_obter_usuario_por_id(client, admin_headers, admin_user):
    r = await client.get(f"/users/{admin_user.id}", headers=admin_headers)
    assert r.status_code == 200
    assert r.json()["id"] == str(admin_user.id)


async def test_atualizar_usuario(client, admin_headers, aluno_user):
    r = await client.patch(f"/users/{aluno_user.id}", headers=admin_headers, json={
        "name": "Nome Atualizado",
        "graduation": "blue",
        "role": "aluno",
    })
    assert r.status_code == 200
    assert r.json()["name"] == "Nome Atualizado"


async def test_excluir_usuario(client, admin_headers, db):
    from app.models import User
    from app.core.security import hash_password

    u = User(email="deletar@test.com", name="Deletar", role="administrador", password_hash=hash_password("123456"))
    db.add(u)
    await db.commit()
    await db.refresh(u)

    r = await client.delete(f"/users/{u.id}", headers=admin_headers)
    assert r.status_code == 204


async def test_pontos_usuario(client, admin_headers, aluno_user):
    r = await client.get(f"/users/{aluno_user.id}/points", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert "points" in data
    assert data["user_id"] == str(aluno_user.id)


async def test_acesso_aluno_lista_propria_academia(client, aluno_headers, aluno_user, academy):
    r = await client.get(f"/users?academy_id={academy.id}", headers=aluno_headers)
    assert r.status_code == 200


async def test_acesso_aluno_lista_outra_academia_proibido(client, aluno_headers, db):
    from app.models import Academy
    from uuid import uuid4

    other = Academy(name="Outra", slug=f"outra-{uuid4().hex[:6]}")
    db.add(other)
    await db.commit()
    await db.refresh(other)

    r = await client.get(f"/users?academy_id={other.id}", headers=aluno_headers)
    assert r.status_code == 403
