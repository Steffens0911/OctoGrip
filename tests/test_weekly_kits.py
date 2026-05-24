"""Kits semanais (1–5 técnicas) e escolha por semana ISO."""

from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.mark.skip(reason="Usa /mission_complete que está desabilitado — endpoint agora retorna 400")
@pytest.mark.asyncio
async def test_weekly_kit_choice_and_week_payload(
    client: AsyncClient,
    db: AsyncSession,
    academy,
    professor_headers: dict,
    aluno_headers: dict,
):
    from app.models import Technique

    t1 = Technique(
        academy_id=academy.id,
        name=f"T1-{uuid4().hex[:6]}",
        slug=f"t1-{uuid4().hex[:6]}",
        base_points=10,
    )
    t2 = Technique(
        academy_id=academy.id,
        name=f"T2-{uuid4().hex[:6]}",
        slug=f"t2-{uuid4().hex[:6]}",
        base_points=10,
    )
    db.add_all([t1, t2])
    await db.commit()
    await db.refresh(t1)
    await db.refresh(t2)

    r = await client.post(
        f"/academies/{academy.id}/weekly-kits",
        headers=professor_headers,
        json={
            "label": "Manhã",
            "sort_order": 0,
            "items": [
                {"technique_id": str(t1.id), "multiplier": 10},
                {"technique_id": str(t2.id), "multiplier": 15},
            ],
        },
    )
    assert r.status_code == 201, r.text
    kit_a = r.json()["id"]

    r = await client.post(
        f"/academies/{academy.id}/weekly-kits",
        headers=professor_headers,
        json={
            "label": "Noite",
            "sort_order": 1,
            "items": [{"technique_id": str(t2.id), "multiplier": 20}],
        },
    )
    assert r.status_code == 201, r.text
    kit_b = r.json()["id"]

    w0 = await client.get("/mission_today/week", headers=aluno_headers)
    assert w0.status_code == 200
    body0 = w0.json()
    assert body0.get("needs_kit_choice") is True
    assert body0.get("selected_kit_id") is None
    assert len(body0.get("entries", [])) == 0
    assert len(body0.get("available_kits", [])) == 2

    r_put = await client.put(
        "/users/me/weekly-kit-choice",
        headers=aluno_headers,
        json={"kit_id": kit_a},
    )
    assert r_put.status_code == 200, r_put.text

    w1 = await client.get("/mission_today/week", headers=aluno_headers)
    assert w1.status_code == 200
    body1 = w1.json()
    assert body1.get("needs_kit_choice") is False
    assert body1.get("selected_kit_id") == kit_a
    entries = body1.get("entries", [])
    assert len(entries) == 2
    assert entries[0]["period_label"] == "Foco 1"
    assert entries[0]["mission"] is not None
    assert entries[1]["mission"] is not None

    missions = await client.get("/missions", headers=professor_headers)
    assert missions.status_code == 200
    m_b_list = [
        m for m in missions.json() if m.get("academy_id") == str(academy.id) and m.get("technique_id") == str(t2.id)
    ]
    mission_b_beginner = next(
        (m for m in m_b_list if m.get("level") == "beginner" and m.get("weekly_kit_id") == kit_b),
        None,
    )
    assert mission_b_beginner is not None
    mid_wrong = mission_b_beginner["id"]

    bad = await client.post(
        "/mission_complete",
        headers=aluno_headers,
        json={"mission_id": str(mid_wrong), "usage_type": "after_training"},
    )
    assert bad.status_code == 403

    m_a_list = [
        m for m in missions.json() if m.get("academy_id") == str(academy.id) and m.get("weekly_kit_id") == kit_a
    ]
    mission_a_beginner = next((m for m in m_a_list if m.get("level") == "beginner" and m.get("slot_index") == 0), None)
    assert mission_a_beginner is not None
    mid_ok = mission_a_beginner["id"]

    ok = await client.post(
        "/mission_complete",
        headers=aluno_headers,
        json={"mission_id": str(mid_ok), "usage_type": "after_training"},
    )
    assert ok.status_code in (200, 201), ok.text

    r_switch = await client.put(
        "/users/me/weekly-kit-choice",
        headers=aluno_headers,
        json={"kit_id": kit_b},
    )
    assert r_switch.status_code == 409


@pytest.mark.asyncio
async def test_weekly_kit_patch_one_to_five(
    client: AsyncClient,
    db: AsyncSession,
    academy,
    professor_headers: dict,
):
    from app.models import Technique

    t1 = Technique(
        academy_id=academy.id,
        name=f"T1-{uuid4().hex[:6]}",
        slug=f"t1-{uuid4().hex[:6]}",
        base_points=10,
    )
    db.add(t1)
    await db.commit()
    await db.refresh(t1)

    r = await client.post(
        f"/academies/{academy.id}/weekly-kits",
        headers=professor_headers,
        json={"label": "Solo", "items": [{"technique_id": str(t1.id), "multiplier": 10}]},
    )
    assert r.status_code == 201
    kit_id = r.json()["id"]

    more = []
    for i in range(4):
        t = Technique(
            academy_id=academy.id,
            name=f"Tx-{i}-{uuid4().hex[:4]}",
            slug=f"tx-{i}-{uuid4().hex[:6]}",
            base_points=10,
        )
        db.add(t)
        more.append(t)
    await db.commit()
    for t in more:
        await db.refresh(t)

    items = [{"technique_id": str(t1.id), "multiplier": 10}]
    items += [{"technique_id": str(t.id), "multiplier": 11} for t in more]
    pr = await client.patch(
        f"/academies/{academy.id}/weekly-kits/{kit_id}",
        headers=professor_headers,
        json={"items": items},
    )
    assert pr.status_code == 200, pr.text
    assert len(pr.json()["items"]) == 5

    bad = await client.patch(
        f"/academies/{academy.id}/weekly-kits/{kit_id}",
        headers=professor_headers,
        json={"items": items + [{"technique_id": str(t1.id), "multiplier": 10}]},
    )
    assert bad.status_code == 400


@pytest.mark.asyncio
async def test_weekly_kits_legacy_underscore_path_matches_hyphen(
    client: AsyncClient,
    academy,
    professor_headers: dict,
):
    """Alias /weekly_kits (underscore) espelha /weekly-kits para clientes antigos."""
    r_hyphen = await client.get(
        f"/academies/{academy.id}/weekly-kits",
        headers=professor_headers,
    )
    r_under = await client.get(
        f"/academies/{academy.id}/weekly_kits",
        headers=professor_headers,
    )
    assert r_hyphen.status_code == 200, r_hyphen.text
    assert r_under.status_code == 200, r_under.text
    assert r_hyphen.json() == r_under.json()


@pytest.mark.asyncio
async def test_kit_missions_in_sync_avoids_redundant_ensure(
    client: AsyncClient,
    db: AsyncSession,
    academy,
    professor_headers: dict,
):
    """Missões já alinhadas ao kit: in_sync True; após alterar multiplier, ensure repõe."""
    from sqlalchemy import update

    from app.models import Mission, Technique
    from app.services.weekly_kit_service import (
        ensure_kit_missions_from_db_items,
        get_kit,
        kit_missions_in_sync_with_items,
    )

    t1 = Technique(
        academy_id=academy.id,
        name=f"T-sync-{uuid4().hex[:6]}",
        slug=f"t-sync-{uuid4().hex[:6]}",
        base_points=10,
    )
    db.add(t1)
    await db.commit()
    await db.refresh(t1)

    r = await client.post(
        f"/academies/{academy.id}/weekly-kits",
        headers=professor_headers,
        json={
            "label": "TurmaSync",
            "items": [{"technique_id": str(t1.id), "multiplier": 15}],
        },
    )
    assert r.status_code == 201, r.text
    kid = UUID(r.json()["id"])

    kit = await get_kit(db, kid, academy.id)
    assert kit is not None
    ordered = sorted(kit.items, key=lambda x: x.order_index)
    items = [(it.technique_id, it.multiplier) for it in ordered]

    assert await kit_missions_in_sync_with_items(db, academy.id, kid, items) is True
    await ensure_kit_missions_from_db_items(db, academy.id, kid)
    assert await kit_missions_in_sync_with_items(db, academy.id, kid, items) is True

    await db.execute(
        update(Mission)
        .where(
            Mission.weekly_kit_id == kid,
            Mission.slot_index == 0,
            Mission.deleted_at.is_(None),
        )
        .values(multiplier=20)
    )
    await db.commit()

    assert await kit_missions_in_sync_with_items(db, academy.id, kid, items) is False
    await ensure_kit_missions_from_db_items(db, academy.id, kid)
    assert await kit_missions_in_sync_with_items(db, academy.id, kid, items) is True
