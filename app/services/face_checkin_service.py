"""
Reconhecimento facial síncrono para o quiosque de chegada.

Diferente do módulo de chamada em lote (face_recognition_tasks.py),
aqui o embedding é gerado diretamente no processo da API (em thread pool)
para garantir resposta imediata ao aluno que se aproxima do quiosque.

Threshold mais restritivo (0.60 vs 0.55 do lote) para reduzir falsos positivos
em ambiente sem supervisão dedicada.
"""

from __future__ import annotations

import logging
import os
import tempfile
from concurrent.futures import ThreadPoolExecutor
from uuid import UUID

import numpy as np
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import StudentFaceEmbedding, User

logger = logging.getLogger(__name__)

KIOSK_CONFIDENCE_THRESHOLD = 0.60

# Pool dedicado para não bloquear workers Uvicorn durante o forward-pass do modelo.
_KIOSK_EXECUTOR = ThreadPoolExecutor(max_workers=2, thread_name_prefix="kiosk_face")


def _generate_embedding_sync(image_bytes: bytes) -> list[float] | None:
    """Gera embedding Facenet512 no thread pool. Frame descartado ao sair."""
    from deepface import DeepFace

    from app.face_model import get_model

    tmp_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            tmp.write(image_bytes)
            tmp_path = tmp.name

        get_model()
        represented = DeepFace.represent(
            img_path=tmp_path,
            model_name="Facenet512",
            detector_backend="opencv",
            enforce_detection=False,
        )
        faces = represented if isinstance(represented, list) else [represented]
        if not faces:
            return None

        embedding_raw = faces[0].get("embedding")
        if not embedding_raw:
            return None

        arr = np.asarray(embedding_raw, dtype=np.float32)
        norm = float(np.linalg.norm(arr))
        if norm > 1e-8:
            arr = arr / norm
        return arr.tolist()
    except Exception:
        logger.warning("Falha ao gerar embedding no quiosque.", exc_info=True)
        return None
    finally:
        if tmp_path:
            try:
                os.remove(tmp_path)
            except OSError:
                pass


async def match_face_for_kiosk(
    image_bytes: bytes,
    academy_id: UUID,
    db: AsyncSession,
) -> tuple[User | None, float]:
    """
    Compara o frame com os embeddings da academia.

    Retorna (aluno correspondente, confiança) ou (None, melhor_sim) se abaixo do threshold.
    """
    import asyncio

    loop = asyncio.get_event_loop()
    query_embedding = await loop.run_in_executor(
        _KIOSK_EXECUTOR,
        _generate_embedding_sync,
        image_bytes,
    )
    if query_embedding is None:
        return None, 0.0

    query_arr = np.asarray(query_embedding, dtype=np.float32)
    dim = int(query_arr.size)

    emb_rows = (
        await db.execute(
            select(StudentFaceEmbedding.student_id, StudentFaceEmbedding.embedding).where(
                StudentFaceEmbedding.academy_id == academy_id
            )
        )
    ).all()

    if not emb_rows:
        return None, 0.0

    known_ids: list[UUID] = []
    known_vecs: list[np.ndarray] = []
    for row in emb_rows:
        emb = row[1]
        if not emb:
            continue
        arr = np.asarray(emb, dtype=np.float32)
        if arr.size != dim:
            continue
        known_ids.append(row[0])
        known_vecs.append(arr)

    if not known_ids:
        return None, 0.0

    matrix = np.vstack(known_vecs)
    similarities = matrix @ query_arr
    best_idx = int(np.argmax(similarities))
    best_sim = max(0.0, min(1.0, float(similarities[best_idx])))

    if best_sim < KIOSK_CONFIDENCE_THRESHOLD:
        return None, best_sim

    student = await db.get(User, known_ids[best_idx])
    return student, best_sim
