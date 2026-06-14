"""Testa o gating LGPD: geração de embedding facial exige consentimento do aluno."""

from unittest.mock import MagicMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User


@pytest.fixture(autouse=True)
def mock_embedding_task():
    """Impede que generate_student_embedding.delay conecte ao broker Celery."""
    mock = MagicMock()
    mock.delay = MagicMock(return_value=None)
    with patch("app.routes.face_recognition.generate_student_embedding", mock):
        yield mock


async def _set_avatar(db: AsyncSession, aluno_user: User) -> None:
    user = await db.get(User, aluno_user.id)
    user.avatar_url = "http://x/avatar.jpg"
    await db.commit()


async def test_generate_embedding_blocked_without_consent(
    client: AsyncClient, db: AsyncSession, gerente_headers: dict, aluno_user: User
):
    await _set_avatar(db, aluno_user)
    r = await client.post(
        f"/face-recognition/generate-embedding/{aluno_user.id}",
        headers=gerente_headers,
    )
    assert r.status_code == 403


async def test_generate_embedding_allowed_with_consent(
    client: AsyncClient,
    db: AsyncSession,
    gerente_headers: dict,
    aluno_user: User,
    aluno_headers: dict,
    mock_embedding_task: MagicMock,
):
    await _set_avatar(db, aluno_user)
    await client.post("/me/consents", headers=aluno_headers, json={"consent_type": "biometric"})

    r = await client.post(
        f"/face-recognition/generate-embedding/{aluno_user.id}",
        headers=gerente_headers,
    )
    assert r.status_code == 200
    assert r.json()["status"] == "queued"
    mock_embedding_task.delay.assert_called_once()
