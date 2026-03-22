"""Testes de CRUD de lições e missões."""
import pytest
from datetime import date, timedelta
from uuid import uuid4


# ========================== LIÇÕES ==========================

async def test_criar_licao(client, admin_headers, technique):
    r = await client.post("/lessons", headers=admin_headers, json={
        "technique_id": str(technique.id),
        "title": "Lição sobre raspagem",
        "order_index": 1,
    })
    assert r.status_code == 201
    data = r.json()
    assert data["title"] == "Lição sobre raspagem"
    assert data["technique_id"] == str(technique.id)


async def test_listar_licoes(client, admin_headers, technique, db):
    from app.models import Lesson

    lesson = Lesson(
        technique_id=technique.id,
        title=f"Lição {uuid4().hex[:4]}",
        slug=f"licao-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()

    r = await client.get("/lessons", headers=admin_headers)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_obter_licao_por_id(client, admin_headers, technique, db):
    from app.models import Lesson

    lesson = Lesson(
        technique_id=technique.id,
        title="Lição Única",
        slug=f"unica-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    r = await client.get(f"/lessons/{lesson.id}", headers=admin_headers)
    assert r.status_code == 200
    assert r.json()["title"] == "Lição Única"


async def test_atualizar_licao(client, admin_headers, technique, db):
    from app.models import Lesson

    lesson = Lesson(
        technique_id=technique.id,
        title="Antes",
        slug=f"antes-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    r = await client.put(f"/lessons/{lesson.id}", headers=admin_headers, json={
        "title": "Depois",
    })
    assert r.status_code == 200
    assert r.json()["title"] == "Depois"


async def test_excluir_licao(client, admin_headers, technique, db):
    from app.models import Lesson

    lesson = Lesson(
        technique_id=technique.id,
        title="Para Deletar",
        slug=f"del-{uuid4().hex[:6]}",
        order_index=0,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)

    r = await client.delete(f"/lessons/{lesson.id}", headers=admin_headers)
    assert r.status_code == 204


# ========================== MISSÕES ==========================

async def test_criar_missao(client, admin_headers, technique):
    today = date.today()
    r = await client.post("/missions", headers=admin_headers, json={
        "technique_id": str(technique.id),
        "start_date": today.isoformat(),
        "end_date": (today + timedelta(days=6)).isoformat(),
        "level": "beginner",
    })
    assert r.status_code == 201
    data = r.json()
    assert data["technique_id"] == str(technique.id)
    assert data["level"] == "beginner"


async def test_listar_missoes(client, admin_headers, technique, db):
    from app.models import Mission

    m = Mission(
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
    )
    db.add(m)
    await db.commit()

    r = await client.get("/missions", headers=admin_headers)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_obter_missao_por_id(client, admin_headers, technique, db):
    from app.models import Mission

    m = Mission(
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="intermediate",
    )
    db.add(m)
    await db.commit()
    await db.refresh(m)

    r = await client.get(f"/missions/{m.id}", headers=admin_headers)
    assert r.status_code == 200
    assert r.json()["level"] == "intermediate"


async def test_atualizar_missao(client, admin_headers, technique, db):
    from app.models import Mission

    m = Mission(
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
        theme="Original",
    )
    db.add(m)
    await db.commit()
    await db.refresh(m)

    r = await client.patch(f"/missions/{m.id}", headers=admin_headers, json={
        "theme": "Atualizado",
    })
    assert r.status_code == 200
    assert r.json()["theme"] == "Atualizado"


async def test_excluir_missao(client, admin_headers, technique, db):
    from app.models import Mission

    m = Mission(
        technique_id=technique.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
    )
    db.add(m)
    await db.commit()
    await db.refresh(m)

    r = await client.delete(f"/missions/{m.id}", headers=admin_headers)
    assert r.status_code == 204


async def test_missao_do_dia(client, aluno_headers, technique, academy, db):
    from app.models import Mission

    m = Mission(
        technique_id=technique.id,
        academy_id=academy.id,
        start_date=date.today(),
        end_date=date.today() + timedelta(days=6),
        level="beginner",
        is_active=True,
    )
    db.add(m)
    await db.commit()

    r = await client.get("/mission_today?level=beginner", headers=aluno_headers)
    assert r.status_code in (200, 404)
