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
