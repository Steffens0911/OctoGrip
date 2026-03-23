"""Histórico e restauração admin (audit_logs)."""
from datetime import datetime

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_admin_audit_history_and_restore_undelete(
    client: AsyncClient, admin_headers: dict, technique, db
):
    from sqlalchemy import select

    from app.models import AuditLog, Technique

    tid = technique.id
    r_del = await client.delete(
        f"/techniques/{tid}?academy_id={technique.academy_id}",
        headers=admin_headers,
    )
    assert r_del.status_code == 204

    r_hist = await client.get(
        f"/admin/audit/technique/{tid}",
        headers=admin_headers,
    )
    assert r_hist.status_code == 200
    body = r_hist.json()
    assert body["total"] >= 1
    assert any(x["action"] == "DELETE" for x in body["items"])

    r_restore = await client.post(
        f"/admin/restore/technique/{tid}",
        headers=admin_headers,
    )
    assert r_restore.status_code == 200
    assert r_restore.json()["mode"] == "undelete"

    t = (await db.execute(select(Technique).where(Technique.id == tid))).scalar_one_or_none()
    assert t is not None
    assert t.deleted_at is None

    logs = (
        await db.execute(select(AuditLog).where(AuditLog.entity_id == tid))
    ).scalars().all()
    assert any(log.action == "RESTORE" for log in logs)


@pytest.mark.asyncio
async def test_admin_restore_snapshot_from_update_log(
    client: AsyncClient, admin_headers: dict, technique, db
):
    from sqlalchemy import select

    from app.models import AuditLog, Technique

    tid = technique.id
    original_name = technique.name
    new_name = f"{original_name}-renamed"

    r_put = await client.put(
        f"/techniques/{tid}?academy_id={technique.academy_id}",
        headers=admin_headers,
        json={"name": new_name},
    )
    assert r_put.status_code == 200

    log_row = (
        await db.execute(
            select(AuditLog)
            .where(
                AuditLog.entity == "Technique",
                AuditLog.entity_id == tid,
                AuditLog.action == "UPDATE",
            )
            .order_by(AuditLog.created_at.desc())
        )
    ).scalars().first()
    assert log_row is not None
    log_id = log_row.id

    r_snap = await client.post(
        f"/admin/restore/technique/{tid}?audit_log_id={log_id}",
        headers=admin_headers,
    )
    assert r_snap.status_code == 200
    assert r_snap.json()["mode"] == "snapshot"

    await db.refresh(technique)
    t = (await db.execute(select(Technique).where(Technique.id == tid))).scalar_one()
    assert t.name == original_name


@pytest.mark.asyncio
async def test_non_admin_cannot_audit_restore(client: AsyncClient, professor_headers: dict, technique):
    tid = technique.id
    r = await client.get(f"/admin/audit/technique/{tid}", headers=professor_headers)
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_admin_audit_feed_all_and_academy_filter(
    client: AsyncClient, admin_headers: dict, technique,
):
    """Feed global: após alteração, log aparece; filtro por academia e entity funciona."""
    tid = technique.id
    aid = str(technique.academy_id)

    await client.put(
        f"/techniques/{tid}?academy_id={aid}",
        headers=admin_headers,
        json={"name": f"{technique.name}-feed-marker"},
    )

    r_feed = await client.get("/admin/audit/feed?limit=30&order=desc", headers=admin_headers)
    assert r_feed.status_code == 200
    body_all = r_feed.json()
    assert body_all["total"] >= 1
    assert any(x["entity_id"] == str(tid) for x in body_all["items"])

    r_filt = await client.get(
        f"/admin/audit/feed?academy_id={aid}&limit=200&order=desc",
        headers=admin_headers,
    )
    assert r_filt.status_code == 200
    body_f = r_filt.json()
    for item in body_f["items"]:
        assert item["entity"] in ("Technique", "Lesson", "Mission", "Trophy")
    assert any(x["entity_id"] == str(tid) for x in body_f["items"])

    r_tech_only = await client.get(
        f"/admin/audit/feed?academy_id={aid}&entity=technique&limit=50",
        headers=admin_headers,
    )
    assert r_tech_only.status_code == 200
    for item in r_tech_only.json()["items"]:
        assert item["entity"] == "Technique"


@pytest.mark.asyncio
async def test_admin_audit_history_order_desc(client: AsyncClient, admin_headers: dict, technique):
    tid = technique.id
    await client.put(
        f"/techniques/{tid}?academy_id={technique.academy_id}",
        headers=admin_headers,
        json={"name": f"{technique.name}-audit-a"},
    )
    await client.put(
        f"/techniques/{tid}?academy_id={technique.academy_id}",
        headers=admin_headers,
        json={"name": f"{technique.name}-audit-b"},
    )
    r = await client.get(
        f"/admin/audit/technique/{tid}?order=desc&limit=20",
        headers=admin_headers,
    )
    assert r.status_code == 200
    body = r.json()
    assert body["order"] == "desc"
    items = body["items"]
    assert len(items) >= 2
    t0 = datetime.fromisoformat(items[0]["created_at"].replace("Z", "+00:00"))
    t1 = datetime.fromisoformat(items[1]["created_at"].replace("Z", "+00:00"))
    assert t0 >= t1
