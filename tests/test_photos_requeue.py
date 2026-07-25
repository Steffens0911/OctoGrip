"""Testes da reconciliação de posts presos em "processing" (OctoPhotos).

O post é commitado com status="processing" antes de a task de resize ser enfileirada.
Se a mensagem se perder no broker, nada reprocessa — daí a varredura periódica.
"""

from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password_sync
from app.models import Academy, User
from app.models.academy_photo import AcademyPhoto
from app.tasks.photo_tasks import requeue_stuck_photos

# ─── helpers ────────────────────────────────────────────────────────────────


async def _make_academy(db: AsyncSession) -> Academy:
    a = Academy(
        name=f"Acad {uuid4().hex[:6]}",
        slug=f"acad-{uuid4().hex[:6]}",
        octophotos_enabled=True,
    )
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


async def _make_user(db: AsyncSession, *, academy: Academy) -> tuple[User, str]:
    u = User(
        email=f"aluno-{uuid4().hex[:8]}@test.com",
        name="Aluno Teste",
        role="aluno",
        academy_id=academy.id,
        password_hash=hash_password_sync("pass1234"),
    )
    db.add(u)
    await db.commit()
    await db.refresh(u)
    return u, create_access_token(u.id)


async def _make_photo(
    db: AsyncSession,
    *,
    academy: Academy,
    author: User,
    raw_file_path: str | None,
    status: str = "processing",
    age_minutes: int = 30,
    deleted: bool = False,
) -> AcademyPhoto:
    now = datetime.now(UTC)
    photo = AcademyPhoto(
        academy_id=academy.id,
        author_id=author.id,
        raw_file_path=raw_file_path,
        status=status,
        created_at=now - timedelta(minutes=age_minutes),
        updated_at=now - timedelta(minutes=age_minutes),
        deleted_at=now if deleted else None,
    )
    db.add(photo)
    await db.commit()
    await db.refresh(photo)
    return photo


def _raw_file(tmp_path) -> str:
    path = tmp_path / f"{uuid4().hex}_raw.jpeg"
    path.write_bytes(b"conteudo-bruto")
    return str(path)


def _run_requeue() -> tuple[MagicMock, int]:
    """Executa a varredura com o dispatch mockado. Retorna (mock, total reenfileirado)."""
    mock_task = MagicMock()
    with patch("app.tasks.photo_tasks.process_photo_upload", mock_task):
        total = requeue_stuck_photos()
    return mock_task, total


def _delayed_ids(mock_task: MagicMock) -> set[str]:
    return {call.args[0] for call in mock_task.delay.call_args_list}


# ─── varredura ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_requeue_reenfileira_post_preso(db: AsyncSession, tmp_path):
    academy = await _make_academy(db)
    author, _ = await _make_user(db, academy=academy)
    raw = _raw_file(tmp_path)
    photo = await _make_photo(db, academy=academy, author=author, raw_file_path=raw)

    mock_task, total = _run_requeue()

    assert str(photo.id) in _delayed_ids(mock_task)
    assert total >= 1
    mock_task.delay.assert_any_call(str(photo.id), raw)

    await db.commit()
    await db.refresh(photo)
    assert photo.status == "processing"  # o worker é quem promove para "ready"


@pytest.mark.asyncio
async def test_requeue_ignora_post_recente(db: AsyncSession, tmp_path):
    """Post recém-criado pode ter task em voo (ou em retry) — não redisparar."""
    academy = await _make_academy(db)
    author, _ = await _make_user(db, academy=academy)
    photo = await _make_photo(
        db,
        academy=academy,
        author=author,
        raw_file_path=_raw_file(tmp_path),
        age_minutes=0,
    )

    mock_task, _ = _run_requeue()

    assert str(photo.id) not in _delayed_ids(mock_task)


@pytest.mark.asyncio
async def test_requeue_ignora_post_deletado(db: AsyncSession, tmp_path):
    academy = await _make_academy(db)
    author, _ = await _make_user(db, academy=academy)
    photo = await _make_photo(
        db,
        academy=academy,
        author=author,
        raw_file_path=_raw_file(tmp_path),
        deleted=True,
    )

    mock_task, _ = _run_requeue()

    assert str(photo.id) not in _delayed_ids(mock_task)


@pytest.mark.asyncio
async def test_requeue_ignora_post_ja_pronto(db: AsyncSession, tmp_path):
    academy = await _make_academy(db)
    author, _ = await _make_user(db, academy=academy)
    photo = await _make_photo(
        db,
        academy=academy,
        author=author,
        raw_file_path=_raw_file(tmp_path),
        status="ready",
    )

    mock_task, _ = _run_requeue()

    assert str(photo.id) not in _delayed_ids(mock_task)


@pytest.mark.asyncio
async def test_requeue_marca_failed_quando_arquivo_bruto_sumiu(db: AsyncSession, tmp_path):
    academy = await _make_academy(db)
    author, _ = await _make_user(db, academy=academy)
    photo = await _make_photo(
        db,
        academy=academy,
        author=author,
        raw_file_path=str(tmp_path / "nao-existe.jpeg"),
    )

    mock_task, _ = _run_requeue()

    assert str(photo.id) not in _delayed_ids(mock_task)
    await db.commit()
    await db.refresh(photo)
    assert photo.status == "failed"


# ─── endpoint ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_criar_post_com_broker_fora_ainda_retorna_201(client: AsyncClient, db: AsyncSession):
    """Upload e registro já persistiram: falha no broker não deve virar 500 para o autor."""
    import io

    from PIL import Image

    academy = await _make_academy(db)
    _, token = await _make_user(db, academy=academy)

    buf = io.BytesIO()
    Image.new("RGB", (10, 10), color=(255, 255, 255)).save(buf, "JPEG")

    mock_task = MagicMock()
    mock_task.delay.side_effect = OSError("broker indisponível")
    with patch("app.tasks.photo_tasks.process_photo_upload", mock_task):
        r = await client.post(
            f"/academies/{academy.id}/photos",
            headers={"Authorization": f"Bearer {token}"},
            files={"file": ("foto.jpg", buf.getvalue(), "image/jpeg")},
            data={"caption": "Treino"},
        )

    assert r.status_code == 201
    assert r.json()["status"] == "processing"
    mock_task.delay.assert_called_once()
