"""Marketplace por academia: CRUD (gestor/professor) e leitura para aluno via /me."""
from urllib.parse import parse_qs, unquote, urlparse
from uuid import uuid4

import pytest
from app.core.security import create_access_token, hash_password_sync
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


def _item_json(**overrides):
    base = {
        "title": f"Kimono {uuid4().hex[:6]}",
        "description": "Tamanho A2",
        "price_cents": 45000,
        "currency": "BRL",
        "image_url": "https://example.com/p.jpg",
        "whatsapp_ddd": "11",
        "whatsapp_number": "999999999",
        "sort_order": 0,
        "is_active": True,
    }
    base.update(overrides)
    return base


@pytest.mark.asyncio
async def test_professor_creates_aluno_lists_me_marketplace(
    client: AsyncClient,
    academy,
    professor_headers: dict,
    aluno_headers: dict,
):
    r = await client.post("/marketplace_items", headers=professor_headers, json=_item_json())
    assert r.status_code == 201, r.text
    data = r.json()
    item_id = data["id"]
    assert data["academy_id"] == str(academy.id)
    assert data["title"].startswith("Kimono")
    assert data["whatsapp_ddd"] == "11"
    assert data["whatsapp_number"] == "999999999"
    assert data["whatsapp_url"] is not None
    assert "wa.me/5511999999999" in data["whatsapp_url"]

    r_me = await client.get("/me/marketplace_items", headers=aluno_headers)
    assert r_me.status_code == 200, r_me.text
    items = r_me.json()
    assert len(items) == 1
    assert items[0]["id"] == item_id
    assert items[0]["price_cents"] == 45000
    assert items[0]["whatsapp_url"] is not None
    assert items[0]["description"] == "Tamanho A2"
    parsed = urlparse(items[0]["whatsapp_url"])
    qs = parse_qs(parsed.query)
    text = unquote(qs["text"][0])
    assert "Kimono" in text or "produto" in text.lower()


@pytest.mark.asyncio
async def test_create_without_whatsapp_optional(
    client: AsyncClient,
    academy,
    professor_headers: dict,
    aluno_headers: dict,
):
    body = _item_json()
    del body["whatsapp_ddd"]
    del body["whatsapp_number"]
    r = await client.post("/marketplace_items", headers=professor_headers, json=body)
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["whatsapp_url"] is None
    assert data["whatsapp_ddd"] is None
    assert data["whatsapp_number"] is None

    r_me = await client.get("/me/marketplace_items", headers=aluno_headers)
    assert r_me.status_code == 200
    row = r_me.json()[0]
    assert row.get("whatsapp_url") is None


@pytest.mark.asyncio
async def test_partial_whatsapp_rejected(
    client: AsyncClient,
    academy,
    professor_headers: dict,
):
    body = _item_json()
    del body["whatsapp_ddd"]
    r = await client.post("/marketplace_items", headers=professor_headers, json=body)
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_me_marketplace_inactive_hidden(
    client: AsyncClient,
    academy,
    professor_headers: dict,
    aluno_headers: dict,
):
    r = await client.post("/marketplace_items", headers=professor_headers, json=_item_json(is_active=False))
    assert r.status_code == 201, r.text

    r_me = await client.get("/me/marketplace_items", headers=aluno_headers)
    assert r_me.status_code == 200
    assert r_me.json() == []


@pytest.mark.asyncio
async def test_me_marketplace_empty_without_academy(
    client: AsyncClient,
    db: AsyncSession,
    admin_headers: dict,
):
    from app.models import User

    u = User(
        email=f"no-acad-{uuid4().hex[:8]}@test.com",
        name="Só App",
        role="aluno",
        graduation="white",
        academy_id=None,
        password_hash=hash_password_sync("x12345678"),
    )
    db.add(u)
    await db.commit()
    await db.refresh(u)

    tok = create_access_token(u.id)
    r_me = await client.get("/me/marketplace_items", headers={"Authorization": f"Bearer {tok}"})
    assert r_me.status_code == 200
    assert r_me.json() == []


@pytest.mark.asyncio
async def test_cross_academy_not_visible_on_me(
    client: AsyncClient,
    db: AsyncSession,
    academy,
    professor_headers: dict,
    aluno_headers: dict,
):
    from app.models import Academy, User

    a2 = Academy(name=f"Outra {uuid4().hex[:6]}", slug=f"out-{uuid4().hex[:6]}")
    db.add(a2)
    await db.commit()
    await db.refresh(a2)

    other_aluno = User(
        email=f"aluno2-{uuid4().hex[:8]}@test.com",
        name="Aluno 2",
        role="aluno",
        graduation="white",
        academy_id=a2.id,
        password_hash=hash_password_sync("aluno222"),
    )
    db.add(other_aluno)
    await db.commit()
    await db.refresh(other_aluno)
    other_headers = {"Authorization": f"Bearer {create_access_token(other_aluno.id)}"}

    r = await client.post("/marketplace_items", headers=professor_headers, json=_item_json())
    assert r.status_code == 201, r.text

    r_me = await client.get("/me/marketplace_items", headers=other_headers)
    assert r_me.status_code == 200
    assert r_me.json() == []

    r_me_ok = await client.get("/me/marketplace_items", headers=aluno_headers)
    assert len(r_me_ok.json()) == 1


@pytest.mark.asyncio
async def test_professor_cannot_edit_other_academy_item(
    client: AsyncClient,
    db: AsyncSession,
    academy,
    professor_user,
    professor_headers: dict,
):
    from app.models import Academy, AcademyMarketplaceItem, User

    a2 = Academy(name=f"Acad2-{uuid4().hex[:6]}", slug=f"ac2-{uuid4().hex[:6]}")
    db.add(a2)
    await db.commit()
    await db.refresh(a2)

    prof2 = User(
        email=f"prof2-{uuid4().hex[:8]}@test.com",
        name="Prof 2",
        role="professor",
        graduation="black",
        academy_id=a2.id,
        password_hash=hash_password_sync("prof2222"),
    )
    db.add(prof2)
    await db.commit()
    await db.refresh(prof2)

    item = AcademyMarketplaceItem(
        academy_id=a2.id,
        title="Produto outra",
        description=None,
        price_cents=100,
        currency="BRL",
        image_url=None,
        whatsapp_phone="5511888888888",
        sort_order=0,
        is_active=True,
        created_by_id=prof2.id,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)

    r = await client.put(
        f"/marketplace_items/{item.id}",
        headers=professor_headers,
        json={"title": "Hack"},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_admin_create_requires_academy_id(
    client: AsyncClient,
    academy,
    admin_headers: dict,
):
    r = await client.post("/marketplace_items", headers=admin_headers, json=_item_json())
    assert r.status_code == 400

    r_ok = await client.post(
        "/marketplace_items",
        headers=admin_headers,
        json=_item_json(academy_id=str(academy.id)),
    )
    assert r_ok.status_code == 201, r_ok.text
    assert r_ok.json()["academy_id"] == str(academy.id)
