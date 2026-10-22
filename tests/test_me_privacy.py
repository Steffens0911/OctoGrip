"""Testes dos direitos do titular (LGPD): consentimentos, exportação e exclusão."""

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import StudentFaceEmbedding, User


async def test_consents_default_all_not_granted(client: AsyncClient, aluno_headers: dict):
    r = await client.get("/me/consents", headers=aluno_headers)
    assert r.status_code == 200
    items = {i["consent_type"]: i for i in r.json()["items"]}
    assert set(items) == {"terms", "privacy", "biometric"}
    assert items["biometric"]["granted"] is False
    assert items["biometric"]["up_to_date"] is False


async def test_grant_consent_marks_up_to_date(client: AsyncClient, aluno_headers: dict):
    r = await client.post(
        "/me/consents",
        headers=aluno_headers,
        json={"consent_type": "biometric", "granted": True},
    )
    assert r.status_code == 200
    items = {i["consent_type"]: i for i in r.json()["items"]}
    assert items["biometric"]["granted"] is True
    assert items["biometric"]["up_to_date"] is True
    assert items["biometric"]["current_version"] is not None


async def test_revoke_biometric_purges_embedding(
    client: AsyncClient, db: AsyncSession, aluno_user: User, aluno_headers: dict
):
    # Concede consentimento e cria embedding + foto facial.
    await client.post("/me/consents", headers=aluno_headers, json={"consent_type": "biometric"})
    db.add(
        StudentFaceEmbedding(
            student_id=aluno_user.id,
            academy_id=aluno_user.academy_id,
            embedding=[0.1, 0.2, 0.3],
        )
    )
    user = await db.get(User, aluno_user.id)
    user.facial_photo_url = "http://x/face.jpg"
    await db.commit()

    r = await client.delete("/me/consents/biometric", headers=aluno_headers)
    assert r.status_code == 204

    rows = (
        (await db.execute(select(StudentFaceEmbedding).where(StudentFaceEmbedding.student_id == aluno_user.id)))
        .scalars()
        .all()
    )
    assert rows == []

    r2 = await client.get("/me/consents", headers=aluno_headers)
    items = {i["consent_type"]: i for i in r2.json()["items"]}
    assert items["biometric"]["granted"] is False


async def test_data_export_returns_profile(client: AsyncClient, aluno_user: User, aluno_headers: dict):
    r = await client.get("/me/data-export", headers=aluno_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["profile"]["id"] == str(aluno_user.id)
    assert data["profile"]["email"] == aluno_user.email
    assert "consents" in data
    assert "related_data" in data


async def test_delete_account_anonymizes(client: AsyncClient, db: AsyncSession, aluno_user: User, aluno_headers: dict):
    original_email = aluno_user.email
    user_id = aluno_user.id
    r = await client.delete("/me/account", headers=aluno_headers)
    assert r.status_code == 200
    assert r.json()["status"] == "anonymized"

    db.expire_all()
    user = await db.get(User, user_id)
    assert user.email != original_email
    assert user.name == "Usuário removido"
    assert user.password_hash is None
    assert user.facial_photo_url is None
    assert user.account_frozen is True


async def test_delete_account_erases_feed_content(
    client: AsyncClient,
    db: AsyncSession,
    aluno_user: User,
    professor_user: User,
    aluno_headers: dict,
):
    """Fotos, comentários, curtidas e menções do titular saem do feed; arquivos são apagados."""
    from uuid import uuid4

    from app.models.academy_photo import AcademyPhoto, AcademyPhotoComment, AcademyPhotoLike
    from app.services.photos_service import media_url_to_path

    tag = uuid4().hex[:8]
    image_url, thumb_url = f"/media/photos/test-{tag}.jpg", f"/media/photos/test-{tag}_thumb.jpg"
    files = [media_url_to_path(image_url), media_url_to_path(thumb_url)]
    for path in files:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"jpeg")

    aluno_id, professor_id = aluno_user.id, professor_user.id
    mention = f"@[Aluno Teste|{aluno_id}]"
    try:
        own = AcademyPhoto(
            academy_id=aluno_user.academy_id,
            author_id=aluno_user.id,
            image_url=image_url,
            thumbnail_url=thumb_url,
            status="ready",
        )
        system_post = AcademyPhoto(
            academy_id=aluno_user.academy_id,
            author_id=aluno_user.id,
            status="ready",
            is_system_post=True,
            system_post_type="trophy",
            system_post_ref_id=uuid4(),
            caption="Aluno Teste conquistou um troféu",
        )
        other = AcademyPhoto(
            academy_id=aluno_user.academy_id,
            author_id=professor_user.id,
            status="ready",
            caption=f"Treino com {mention}",
            comments_count=2,
            likes_count=1,
        )
        db.add_all([own, system_post, other])
        await db.flush()
        db.add_all(
            [
                AcademyPhotoComment(photo_id=other.id, author_id=aluno_user.id, body="Valeu, professor!"),
                AcademyPhotoComment(photo_id=other.id, author_id=professor_user.id, body=f"Boa, {mention}"),
                AcademyPhotoComment(photo_id=own.id, author_id=professor_user.id, body="Bela foto"),
                AcademyPhotoLike(photo_id=other.id, user_id=aluno_user.id),
            ]
        )
        await db.commit()
        own_id, system_id, other_id = own.id, system_post.id, other.id

        r = await client.delete("/me/account", headers=aluno_headers)
        assert r.status_code == 200

        db.expire_all()
        assert await db.get(AcademyPhoto, own_id) is None
        assert await db.get(AcademyPhoto, system_id) is None
        assert all(not path.exists() for path in files)

        kept = await db.get(AcademyPhoto, other_id)
        assert kept is not None
        assert kept.comments_count == 1
        assert kept.likes_count == 0
        assert str(aluno_id) in kept.caption and "Aluno Teste" not in kept.caption
        assert "Usuário removido" in kept.caption

        comments = (
            (await db.execute(select(AcademyPhotoComment).where(AcademyPhotoComment.photo_id == other_id)))
            .scalars()
            .all()
        )
        assert [c.author_id for c in comments] == [professor_id]
        assert comments[0].body == f"Boa, @[Usuário removido|{aluno_id}]"

        likes = (await db.execute(select(AcademyPhotoLike).where(AcademyPhotoLike.user_id == aluno_id))).all()
        assert likes == []
    finally:
        for path in files:
            path.unlink(missing_ok=True)
