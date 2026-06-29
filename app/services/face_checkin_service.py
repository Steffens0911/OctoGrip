"""
Reconhecimento facial do quiosque de chegada — orquestração na API.

A inferência pesada (DeepFace/TensorFlow) roda no worker Celery dedicado da fila
``face`` — modelo Facenet512 pré-carregado e quente, pool solo, memória isolada — e
**nunca** no processo web da API. O endpoint apenas:

  1. despacha o frame ao worker e aguarda o embedding (com timeout);
  2. compara o embedding com os da academia (numpy, leve);
  3. devolve o aluno correspondente.

Esta separação elimina o OOM/502 que ocorria quando o uvicorn carregava o modelo
(~1.5 GB por worker) durante o request, e mantém a CPU da API estável durante os
treinos. Threshold mais restritivo (0.60 vs 0.55 do lote) para reduzir falsos
positivos no quiosque sem supervisão dedicada.
"""

from __future__ import annotations

import asyncio
import base64
import logging
from concurrent.futures import ThreadPoolExecutor
from uuid import UUID

import numpy as np
from celery.exceptions import TimeoutError as CeleryTimeoutError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.exceptions import KioskInferenceUnavailableError
from app.models import StudentFaceEmbedding, User

logger = logging.getLogger(__name__)

KIOSK_CONFIDENCE_THRESHOLD = 0.60

# Pool pequeno apenas para AGUARDAR (bloqueante) o resultado da task no result backend.
# São threads ociosas esperando no Redis — não consomem CPU; isolam a espera do
# executor default do event loop, que serve o resto da API.
_KIOSK_WAIT_EXECUTOR = ThreadPoolExecutor(max_workers=4, thread_name_prefix="kiosk_wait")


async def _embed_via_worker(image_bytes: bytes) -> list[float] | None:
    """
    Delega a geração do embedding ao worker da fila ``face`` e aguarda o resultado.

    Retorna o embedding L2-normalizado, ou ``None`` quando o worker processou mas não
    encontrou face utilizável. Levanta :class:`KioskInferenceUnavailableError` (503,
    retentável) se o worker estiver indisponível ou demorar além de
    ``KIOSK_EMBED_TIMEOUT_SEC`` — falha de infra, não "rosto desconhecido".
    """
    from app.tasks.face_recognition_tasks import generate_kiosk_embedding

    frame_b64 = base64.b64encode(image_bytes).decode("ascii")

    try:
        async_result = generate_kiosk_embedding.apply_async(args=[frame_b64], queue="face")
    except Exception:  # broker indisponível, fila inacessível, etc.
        logger.warning("Falha ao despachar embedding do quiosque ao worker de visão.", exc_info=True)
        raise KioskInferenceUnavailableError() from None

    loop = asyncio.get_event_loop()
    try:
        payload = await loop.run_in_executor(
            _KIOSK_WAIT_EXECUTOR,
            lambda: async_result.get(timeout=settings.KIOSK_EMBED_TIMEOUT_SEC, propagate=True),
        )
    except CeleryTimeoutError:
        logger.warning("Timeout aguardando embedding do quiosque (worker de visão lento/indisponível).")
        raise KioskInferenceUnavailableError() from None
    except Exception:
        # Exceção propagada da própria task (erro inesperado na inferência).
        logger.warning("Erro na task de embedding do quiosque.", exc_info=True)
        raise KioskInferenceUnavailableError() from None
    finally:
        # Não deixa biometria (embedding) parada no result backend até expirar.
        try:
            async_result.forget()
        except Exception:
            pass

    if not isinstance(payload, dict):
        raise KioskInferenceUnavailableError()
    embedding = payload.get("embedding")
    if not embedding:
        return None
    return embedding


async def match_face_for_kiosk(
    image_bytes: bytes,
    academy_id: UUID,
    db: AsyncSession,
) -> tuple[User | None, float]:
    """
    Identifica o aluno a partir do frame do quiosque.

    Retorna ``(aluno, confiança)`` se a melhor similaridade ≥ threshold, senão
    ``(None, melhor_similaridade)``. Levanta :class:`KioskInferenceUnavailableError`
    se o worker de inferência estiver indisponível (o app retenta).
    """
    query_embedding = await _embed_via_worker(image_bytes)
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
