"""Denunciar e bloquear no feed de fotos (exigência de UGC da Google Play)."""

from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Notification
from app.models.academy_photo import AcademyPhoto, AcademyPhotoComment
from app.models.photo_moderation import AcademyPhotoReport, UserBlock
from tests.test_photos import _make_academy, _make_user, mock_photo_task  # noqa: F401  (fixture autouse)


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def _post(db: AsyncSession, academy, author, caption="treino de hoje") -> AcademyPhoto:
    photo = AcademyPhoto(academy_id=academy.id, author_id=author.id, caption=caption, status="ready")
    db.add(photo)
    await db.commit()
    await db.refresh(photo)
    return photo


async def _comment(db: AsyncSession, photo, author, body="oss!") -> AcademyPhotoComment:
    comment = AcademyPhotoComment(photo_id=photo.id, author_id=author.id, body=body)
    db.add(comment)
    photo.comments_count += 1
    await db.commit()
    await db.refresh(comment)
    return comment


@pytest.fixture
async def cena(db: AsyncSession):
    """Academia com feed ligado: autor, denunciante, observador e gerente."""
    academy = await _make_academy(db, octophotos=True)
    autor, t_autor = await _make_user(db, academy=academy)
    denunciante, t_den = await _make_user(db, academy=academy)
    observador, t_obs = await _make_user(db, academy=academy)
    gerente, t_ger = await _make_user(db, academy=academy, role="gerente_academia")
    photo = await _post(db, academy, autor)
    return {
        "academy": academy,
        "autor": autor, "t_autor": t_autor,
        "den": denunciante, "t_den": t_den,
        "obs": observador, "t_obs": t_obs,
        "ger": gerente, "t_ger": t_ger,
        "photo": photo,
    }  # fmt: skip


async def _feed_ids(client: AsyncClient, academy, token: str, **params) -> list[str]:
    r = await client.get(f"/academies/{academy.id}/photos", headers=_h(token), params=params)
    assert r.status_code == 200, r.text
    return [item["id"] for item in r.json()["items"]]


# ─── denunciar post ─────────────────────────────────────────────────────────


async def test_report_photo_hides_it_only_for_the_reporter(client: AsyncClient, cena):
    a, photo = cena["academy"], cena["photo"]
    assert str(photo.id) in await _feed_ids(client, a, cena["t_den"])

    r = await client.post(
        f"/academies/{a.id}/photos/{photo.id}/report", headers=_h(cena["t_den"]), json={"reason": "spam"}
    )
    assert r.status_code == 201
    assert r.json()["status"] == "open" and r.json()["already_reported"] is False

    assert str(photo.id) not in await _feed_ids(client, a, cena["t_den"])
    assert str(photo.id) in await _feed_ids(client, a, cena["t_obs"])  # outros continuam vendo
    got = await client.get(f"/academies/{a.id}/photos/{photo.id}", headers=_h(cena["t_den"]))
    assert got.status_code == 404


async def test_report_same_photo_twice_does_not_duplicate(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    url = f"/academies/{a.id}/photos/{photo.id}/report"
    first = await client.post(url, headers=_h(cena["t_den"]), json={"reason": "nudity", "details": "foto imprópria"})
    again = await client.post(url, headers=_h(cena["t_den"]), json={"reason": "spam"})
    assert again.status_code == 201
    assert again.json()["already_reported"] is True and again.json()["id"] == first.json()["id"]
    total = (
        (await db.execute(select(AcademyPhotoReport).where(AcademyPhotoReport.photo_id == photo.id))).scalars().all()
    )
    assert len(total) == 1 and total[0].reason == "nudity"


async def test_report_notifies_academy_managers(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    await client.post(
        f"/academies/{a.id}/photos/{photo.id}/report", headers=_h(cena["t_den"]), json={"reason": "violence"}
    )
    notifs = (
        (
            await db.execute(
                select(Notification).where(Notification.user_id == cena["ger"].id, Notification.type == "photo_report")
            )
        )
        .scalars()
        .all()
    )
    assert len(notifs) == 1
    assert notifs[0].data["academy_id"] == str(a.id)


async def test_cannot_report_own_post(client: AsyncClient, cena):
    a, photo = cena["academy"], cena["photo"]
    r = await client.post(
        f"/academies/{a.id}/photos/{photo.id}/report", headers=_h(cena["t_autor"]), json={"reason": "spam"}
    )
    assert r.status_code == 400


async def test_report_validates_reason_and_access(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    url = f"/academies/{a.id}/photos/{photo.id}/report"
    assert (await client.post(url, headers=_h(cena["t_den"]), json={"reason": "invalido"})).status_code == 422

    outra = await _make_academy(db, octophotos=True)
    _, t_fora = await _make_user(db, academy=outra)
    assert (await client.post(url, headers=_h(t_fora), json={"reason": "spam"})).status_code == 403

    off = await _make_academy(db, octophotos=False)
    u_off, t_off = await _make_user(db, academy=off)
    p_off = await _post(db, off, u_off)
    assert (
        await client.post(f"/academies/{off.id}/photos/{p_off.id}/report", headers=_h(t_off), json={"reason": "spam"})
    ).status_code == 403


async def test_report_photo_from_another_academy_is_404(client: AsyncClient, db: AsyncSession, cena):
    outra = await _make_academy(db, octophotos=True)
    u, t = await _make_user(db, academy=outra)
    r = await client.post(
        f"/academies/{outra.id}/photos/{cena['photo'].id}/report", headers=_h(t), json={"reason": "spam"}
    )
    assert r.status_code == 404


# ─── denunciar comentário ───────────────────────────────────────────────────


async def test_report_comment_hides_it_only_for_the_reporter(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    comment = await _comment(db, photo, cena["autor"], "comentário ofensivo")
    url = f"/academies/{a.id}/photos/{photo.id}/comments"

    r = await client.post(f"{url}/{comment.id}/report", headers=_h(cena["t_den"]), json={"reason": "harassment"})
    assert r.status_code == 201

    mine = await client.get(url, headers=_h(cena["t_den"]))
    others = await client.get(url, headers=_h(cena["t_obs"]))
    assert [c["id"] for c in mine.json()] == []
    assert [c["id"] for c in others.json()] == [str(comment.id)]
    assert str(photo.id) in await _feed_ids(client, a, cena["t_den"])  # o post continua visível


async def test_cannot_report_own_comment_or_missing_comment(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    comment = await _comment(db, photo, cena["autor"])
    base = f"/academies/{a.id}/photos/{photo.id}/comments"
    assert (
        await client.post(f"{base}/{comment.id}/report", headers=_h(cena["t_autor"]), json={"reason": "spam"})
    ).status_code == 400
    assert (
        await client.post(f"{base}/{uuid4()}/report", headers=_h(cena["t_den"]), json={"reason": "spam"})
    ).status_code == 404


# ─── moderação ──────────────────────────────────────────────────────────────


async def test_only_managers_list_reports(client: AsyncClient, cena):
    a, photo = cena["academy"], cena["photo"]
    await client.post(f"/academies/{a.id}/photos/{photo.id}/report", headers=_h(cena["t_den"]), json={"reason": "spam"})

    assert (await client.get(f"/academies/{a.id}/photos/reports", headers=_h(cena["t_den"]))).status_code == 403
    r = await client.get(f"/academies/{a.id}/photos/reports", headers=_h(cena["t_ger"]))
    assert r.status_code == 200
    item = r.json()[0]
    assert item["target_type"] == "photo" and item["target_text"] == "treino de hoje"
    assert item["reporter_name"] == cena["den"].name and item["target_author_name"] == cena["autor"].name


async def test_manager_of_another_academy_cannot_moderate(client: AsyncClient, db: AsyncSession, cena):
    outra = await _make_academy(db, octophotos=True)
    _, t_outro_ger = await _make_user(db, academy=outra, role="gerente_academia")
    r = await client.get(f"/academies/{cena['academy'].id}/photos/reports", headers=_h(t_outro_ger))
    assert r.status_code == 403


async def test_remove_action_deletes_post_and_closes_all_reports(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    for token in (cena["t_den"], cena["t_obs"]):
        await client.post(f"/academies/{a.id}/photos/{photo.id}/report", headers=_h(token), json={"reason": "nudity"})
    reports = (await client.get(f"/academies/{a.id}/photos/reports", headers=_h(cena["t_ger"]))).json()
    assert len(reports) == 2 and reports[0]["reports_on_target"] == 2

    r = await client.patch(
        f"/academies/{a.id}/photos/reports/{reports[0]['id']}", headers=_h(cena["t_ger"]), json={"action": "remove"}
    )
    assert r.status_code == 200 and r.json()["status"] == "removed" and r.json()["target_removed"] is True

    assert (await client.get(f"/academies/{a.id}/photos/reports", headers=_h(cena["t_ger"]))).json() == []
    assert str(photo.id) not in await _feed_ids(client, a, cena["t_autor"])
    await db.refresh(photo)
    assert photo.deleted_at is not None


async def test_dismiss_action_keeps_the_content(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    await client.post(
        f"/academies/{a.id}/photos/{photo.id}/report", headers=_h(cena["t_den"]), json={"reason": "other"}
    )
    report_id = (await client.get(f"/academies/{a.id}/photos/reports", headers=_h(cena["t_ger"]))).json()[0]["id"]

    r = await client.patch(
        f"/academies/{a.id}/photos/reports/{report_id}", headers=_h(cena["t_ger"]), json={"action": "dismiss"}
    )
    assert r.status_code == 200 and r.json()["status"] == "dismissed"
    await db.refresh(photo)
    assert photo.deleted_at is None
    assert str(photo.id) in await _feed_ids(client, a, cena["t_obs"])


async def test_remove_action_on_comment_decrements_counter(client: AsyncClient, db: AsyncSession, cena):
    a, photo = cena["academy"], cena["photo"]
    comment = await _comment(db, photo, cena["autor"])
    await client.post(
        f"/academies/{a.id}/photos/{photo.id}/comments/{comment.id}/report",
        headers=_h(cena["t_den"]),
        json={"reason": "harassment"},
    )
    report = (await client.get(f"/academies/{a.id}/photos/reports", headers=_h(cena["t_ger"]))).json()[0]
    assert report["target_type"] == "comment" and report["target_text"] == "oss!"

    await client.patch(
        f"/academies/{a.id}/photos/reports/{report['id']}", headers=_h(cena["t_ger"]), json={"action": "remove"}
    )
    await db.refresh(comment)
    await db.refresh(photo)
    assert comment.deleted_at is not None and photo.comments_count == 0


async def test_resolve_unknown_report_is_404(client: AsyncClient, cena):
    r = await client.patch(
        f"/academies/{cena['academy'].id}/photos/reports/{uuid4()}",
        headers=_h(cena["t_ger"]),
        json={"action": "dismiss"},
    )
    assert r.status_code == 404


# ─── bloquear ───────────────────────────────────────────────────────────────


async def test_block_hides_author_everywhere_for_the_blocker_only(client: AsyncClient, db: AsyncSession, cena):
    a, photo, autor = cena["academy"], cena["photo"], cena["autor"]
    comment = await _comment(db, photo, autor)
    other_post = await _post(db, a, cena["obs"], "post de outro aluno")

    r = await client.put(f"/academies/{a.id}/photos/blocks/{autor.id}", headers=_h(cena["t_den"]))
    assert r.status_code == 204

    mine = await _feed_ids(client, a, cena["t_den"])
    assert str(photo.id) not in mine and str(other_post.id) in mine
    assert await _feed_ids(client, a, cena["t_den"], author_id=str(autor.id)) == []
    assert str(photo.id) in await _feed_ids(client, a, cena["t_obs"])
    assert (await client.get(f"/academies/{a.id}/photos/{photo.id}", headers=_h(cena["t_den"]))).status_code == 404

    # comentário do bloqueado em post de terceiro
    third = await client.get(f"/academies/{a.id}/photos/{other_post.id}/comments", headers=_h(cena["t_den"]))
    assert third.status_code == 200
    on_blocked_author = await _comment(db, other_post, autor, "comentário do bloqueado")
    visible = await client.get(f"/academies/{a.id}/photos/{other_post.id}/comments", headers=_h(cena["t_den"]))
    assert [c["id"] for c in visible.json()] == []
    seen_by_other = await client.get(f"/academies/{a.id}/photos/{other_post.id}/comments", headers=_h(cena["t_obs"]))
    assert [c["id"] for c in seen_by_other.json()] == [str(on_blocked_author.id)]
    assert str(comment.id)  # comentário original continua existindo para os demais


async def test_block_is_idempotent_listed_and_reversible(client: AsyncClient, cena):
    a, autor = cena["academy"], cena["autor"]
    url = f"/academies/{a.id}/photos/blocks/{autor.id}"
    assert (await client.put(url, headers=_h(cena["t_den"]))).status_code == 204
    assert (await client.put(url, headers=_h(cena["t_den"]))).status_code == 204

    listed = await client.get(f"/academies/{a.id}/photos/blocks", headers=_h(cena["t_den"]))
    assert [b["user_id"] for b in listed.json()] == [str(autor.id)]
    assert (await client.get(f"/academies/{a.id}/photos/blocks", headers=_h(cena["t_obs"]))).json() == []

    assert (await client.delete(url, headers=_h(cena["t_den"]))).status_code == 204
    assert (await client.get(f"/academies/{a.id}/photos/blocks", headers=_h(cena["t_den"]))).json() == []
    assert str(cena["photo"].id) in await _feed_ids(client, a, cena["t_den"])


async def test_block_rules(client: AsyncClient, db: AsyncSession, cena):
    a = cena["academy"]
    assert (
        await client.put(f"/academies/{a.id}/photos/blocks/{cena['den'].id}", headers=_h(cena["t_den"]))
    ).status_code == 400
    assert (
        await client.put(f"/academies/{a.id}/photos/blocks/{uuid4()}", headers=_h(cena["t_den"]))
    ).status_code == 404

    outra = await _make_academy(db, octophotos=True)
    estranho, _ = await _make_user(db, academy=outra)
    assert (
        await client.put(f"/academies/{a.id}/photos/blocks/{estranho.id}", headers=_h(cena["t_den"]))
    ).status_code == 404

    _, t_fora = await _make_user(db, academy=outra)
    assert (
        await client.put(f"/academies/{a.id}/photos/blocks/{cena['autor'].id}", headers=_h(t_fora))
    ).status_code == 403


async def test_account_deletion_removes_blocks_made_and_received(client: AsyncClient, db: AsyncSession, cena):
    a = cena["academy"]
    await client.put(f"/academies/{a.id}/photos/blocks/{cena['autor'].id}", headers=_h(cena["t_den"]))
    await client.put(f"/academies/{a.id}/photos/blocks/{cena['den'].id}", headers=_h(cena["t_obs"]))
    autor_id, den_id, obs_id = cena["autor"].id, cena["den"].id, cena["obs"].id

    r = await client.delete("/me/account", headers=_h(cena["t_den"]))
    assert r.status_code == 200

    db.expire_all()
    left = (await db.execute(select(UserBlock).where(UserBlock.blocker_id.in_([den_id, obs_id])))).scalars().all()
    assert left == []
    assert autor_id  # o autor segue existindo
