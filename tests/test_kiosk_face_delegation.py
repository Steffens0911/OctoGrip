"""
Testes da delegação do embedding facial do quiosque ao worker Celery.

Garante que match_face_for_kiosk despacha a inferência ao worker de visão (sem rodar
TensorFlow no processo da API), faz o matching vetorial e distingue indisponibilidade
do worker (503 retentável) de rosto desconhecido (resposta 200 normal).

O dispatch Celery é mockado: não há broker/worker real na suíte.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import numpy as np
import pytest
from celery.exceptions import TimeoutError as CeleryTimeoutError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import KioskInferenceUnavailableError
from app.core.security import hash_password_sync

_APPLY_ASYNC = "app.tasks.face_recognition_tasks.generate_kiosk_embedding.apply_async"


def _unit(vec: list[float]) -> list[float]:
    """Vetor L2-normalizado (formato em que os embeddings são armazenados/comparados)."""
    arr = np.asarray(vec, dtype=np.float32)
    arr = arr / float(np.linalg.norm(arr))
    return arr.tolist()


class _FakeAsyncResult:
    """Simula o AsyncResult do Celery sem broker/worker reais."""

    def __init__(self, *, result=None, exc=None):
        self._result = result
        self._exc = exc
        self.forgotten = False

    def get(self, timeout=None, propagate=True):
        if self._exc is not None:
            raise self._exc
        return self._result

    def forget(self):
        self.forgotten = True


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
async def kiosk_academy(db: AsyncSession):
    from app.models import Academy

    a = Academy(
        name=f"Kiosk {uuid4().hex[:6]}",
        slug=f"kiosk-{uuid4().hex[:6]}",
        face_recognition_enabled=True,
        face_checkin_enabled=True,
    )
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


@pytest.fixture
async def kiosk_aluno_com_embedding(db: AsyncSession, kiosk_academy):
    from app.models import StudentFaceEmbedding, User

    user = User(
        email=f"kiosk-aluno-{uuid4().hex[:8]}@test.com",
        name="Aluno Kiosk",
        role="aluno",
        graduation="white",
        academy_id=kiosk_academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    emb = _unit([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    db.add(StudentFaceEmbedding(student_id=user.id, academy_id=kiosk_academy.id, embedding=emb))
    await db.commit()
    return user, emb


# ---------------------------------------------------------------------------
# match_face_for_kiosk — delegação + matching
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_match_identifica_aluno(db, kiosk_academy, kiosk_aluno_com_embedding):
    """Worker devolve o embedding do aluno → match acima do threshold; resultado descartado."""
    from app.services.face_checkin_service import match_face_for_kiosk

    user, emb = kiosk_aluno_com_embedding
    fake = _FakeAsyncResult(result={"embedding": emb})
    with patch(_APPLY_ASYNC, return_value=fake) as mock_apply:
        student, sim = await match_face_for_kiosk(b"\xff\xd8\xff frame", kiosk_academy.id, db)

    assert student is not None
    assert student.id == user.id
    assert sim >= 0.60
    # Despachado à fila 'face' (worker dedicado, não a API).
    assert mock_apply.call_args.kwargs.get("queue") == "face"
    # Embedding (biometria) não fica parado no result backend.
    assert fake.forgotten is True


@pytest.mark.asyncio
async def test_match_sem_face_retorna_none(db, kiosk_academy, kiosk_aluno_com_embedding):
    """Worker não detecta face → (None, 0.0), sem erro (resposta normal do endpoint)."""
    from app.services.face_checkin_service import match_face_for_kiosk

    fake = _FakeAsyncResult(result={"embedding": None})
    with patch(_APPLY_ASYNC, return_value=fake):
        student, sim = await match_face_for_kiosk(b"frame", kiosk_academy.id, db)

    assert student is None
    assert sim == 0.0


@pytest.mark.asyncio
async def test_match_abaixo_threshold(db, kiosk_academy, kiosk_aluno_com_embedding):
    """Embedding ortogonal ao do aluno → similaridade < 0.60 → (None, sim)."""
    from app.services.face_checkin_service import match_face_for_kiosk

    other = _unit([0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    fake = _FakeAsyncResult(result={"embedding": other})
    with patch(_APPLY_ASYNC, return_value=fake):
        student, sim = await match_face_for_kiosk(b"frame", kiosk_academy.id, db)

    assert student is None
    assert sim < 0.60


@pytest.mark.asyncio
async def test_match_timeout_levanta_503(db, kiosk_academy, kiosk_aluno_com_embedding):
    """Timeout aguardando o worker → KioskInferenceUnavailableError (503 retentável)."""
    from app.services.face_checkin_service import match_face_for_kiosk

    fake = _FakeAsyncResult(exc=CeleryTimeoutError("timeout"))
    with patch(_APPLY_ASYNC, return_value=fake):
        with pytest.raises(KioskInferenceUnavailableError) as ei:
            await match_face_for_kiosk(b"frame", kiosk_academy.id, db)

    assert ei.value.status_code == 503
    assert fake.forgotten is True  # libera o backend mesmo no caminho de erro


@pytest.mark.asyncio
async def test_match_broker_indisponivel_levanta_503(db, kiosk_academy):
    """Falha ao despachar (broker down) → KioskInferenceUnavailableError (503)."""
    from app.services.face_checkin_service import match_face_for_kiosk

    with patch(_APPLY_ASYNC, side_effect=RuntimeError("broker down")):
        with pytest.raises(KioskInferenceUnavailableError) as ei:
            await match_face_for_kiosk(b"frame", kiosk_academy.id, db)

    assert ei.value.status_code == 503


# ---------------------------------------------------------------------------
# Endpoint — propagação do 503
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_face_arrive_worker_indisponivel_retorna_503(client, db, kiosk_academy):
    """Worker indisponível → endpoint devolve 503 (com CORS), e o app retenta."""
    from app.models import AttendanceSession, User

    prof = User(
        email=f"prof-kiosk-{uuid4().hex[:8]}@test.com",
        name="Prof Kiosk",
        role="professor",
        graduation="black",
        academy_id=kiosk_academy.id,
        password_hash=hash_password_sync("x"),
    )
    db.add(prof)
    await db.commit()
    await db.refresh(prof)

    att = AttendanceSession(
        academy_id=kiosk_academy.id,
        created_by_user_id=prof.id,
        status="active",
        starts_at=datetime.now(UTC),
        expires_at=datetime.now(UTC) + timedelta(hours=2),
    )
    db.add(att)
    await db.commit()
    await db.refresh(att)

    with patch("app.routes.face_checkin.match_face_for_kiosk", new_callable=AsyncMock) as mock_match:
        mock_match.side_effect = KioskInferenceUnavailableError()
        r = await client.post(
            f"/attendance/sessions/{att.id}/face-arrive",
            files={"frame": ("frame.jpg", b"\xff\xd8\xff" + b"\x00" * 100, "image/jpeg")},
        )

    assert r.status_code == 503
