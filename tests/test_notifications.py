"""Testes para as rotas de notificações in-app."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.notification_service import (
    create_notification,
    get_unread_count,
    list_notifications,
    mark_all_as_read,
    mark_as_read,
)


# ---------------------------------------------------------------------------
# Service-level tests
# ---------------------------------------------------------------------------


async def test_create_notification(db: AsyncSession, aluno_user):
    notif = await create_notification(
        db,
        user_id=aluno_user.id,
        type="announcement_global",
        title="Teste",
        body="Corpo do teste",
    )
    assert notif.id is not None
    assert notif.user_id == aluno_user.id
    assert notif.title == "Teste"
    assert notif.read is False


async def test_unread_count_increments(db: AsyncSession, aluno_user):
    initial = await get_unread_count(db, aluno_user.id)
    await create_notification(db, user_id=aluno_user.id, type="video_new", title="T", body="B")
    after = await get_unread_count(db, aluno_user.id)
    assert after == initial + 1


async def test_mark_as_read(db: AsyncSession, aluno_user):
    notif = await create_notification(
        db, user_id=aluno_user.id, type="trophy_earned", title="T", body="B"
    )
    assert notif.read is False
    await mark_as_read(db, notif.id, aluno_user.id)
    count = await get_unread_count(db, aluno_user.id)
    notifications = await list_notifications(db, aluno_user.id, limit=50)
    found = next((n for n in notifications if n.id == notif.id), None)
    assert found is not None
    assert found.read is True


async def test_mark_all_as_read(db: AsyncSession, aluno_user):
    for i in range(3):
        await create_notification(
            db, user_id=aluno_user.id, type="announcement_academy", title=f"N{i}", body="B"
        )
    await mark_all_as_read(db, aluno_user.id)
    count = await get_unread_count(db, aluno_user.id)
    assert count == 0


async def test_list_notifications_unread_only(db: AsyncSession, aluno_user):
    notif_unread = await create_notification(
        db, user_id=aluno_user.id, type="video_new", title="Unread", body="B"
    )
    notif_read = await create_notification(
        db, user_id=aluno_user.id, type="video_new", title="Read", body="B"
    )
    await mark_as_read(db, notif_read.id, aluno_user.id)

    unread_list = await list_notifications(db, aluno_user.id, limit=50, unread_only=True)
    ids = [n.id for n in unread_list]
    assert notif_unread.id in ids
    assert notif_read.id not in ids


# ---------------------------------------------------------------------------
# HTTP route tests
# ---------------------------------------------------------------------------


async def test_list_notifications_endpoint(client: AsyncClient, aluno_user, aluno_headers, db):
    await create_notification(
        db, user_id=aluno_user.id, type="announcement_global", title="HTTP Test", body="B"
    )
    resp = await client.get("/notifications", headers=aluno_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert any(n["title"] == "HTTP Test" for n in data)


async def test_unread_count_endpoint(client: AsyncClient, aluno_user, aluno_headers, db):
    await create_notification(
        db, user_id=aluno_user.id, type="video_new", title="Count Test", body="B"
    )
    resp = await client.get("/notifications/unread-count", headers=aluno_headers)
    assert resp.status_code == 200
    assert resp.json()["count"] >= 1


async def test_mark_read_endpoint(client: AsyncClient, aluno_user, aluno_headers, db):
    notif = await create_notification(
        db, user_id=aluno_user.id, type="trophy_earned", title="Mark Test", body="B"
    )
    resp = await client.post(f"/notifications/{notif.id}/read", headers=aluno_headers)
    assert resp.status_code == 204
    # conferir que ficou como lida
    notifs = await list_notifications(db, aluno_user.id, limit=50)
    found = next((n for n in notifs if n.id == notif.id), None)
    assert found is not None and found.read is True


async def test_mark_all_read_endpoint(client: AsyncClient, aluno_user, aluno_headers, db):
    for i in range(2):
        await create_notification(
            db, user_id=aluno_user.id, type="execution_confirmed", title=f"A{i}", body="B"
        )
    resp = await client.post("/notifications/read-all", headers=aluno_headers)
    assert resp.status_code == 204
    count = await get_unread_count(db, aluno_user.id)
    assert count == 0


async def test_announcement_gerente_only_sua_academia(
    client: AsyncClient, aluno_headers
):
    """Aluno não pode enviar comunicados."""
    resp = await client.post(
        "/notifications/announcement",
        headers=aluno_headers,
        json={"title": "Hack", "body": "tentativa"},
    )
    assert resp.status_code == 403


async def test_announcement_gerente_envia(
    client: AsyncClient, gerente_headers, aluno_user, db
):
    """Gerente da academia pode enviar comunicado."""
    resp = await client.post(
        "/notifications/announcement",
        headers=gerente_headers,
        json={"title": "Comunicado", "body": "Treino cancelado"},
    )
    assert resp.status_code == 204


async def test_announcement_admin_global(
    client: AsyncClient, admin_headers, aluno_user, db
):
    """Admin envia comunicado global."""
    resp = await client.post(
        "/notifications/announcement",
        headers=admin_headers,
        json={"title": "Global", "body": "Aviso para todos"},
    )
    assert resp.status_code == 204
