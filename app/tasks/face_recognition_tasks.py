from __future__ import annotations

import asyncio
import base64
import io
import os
import tempfile
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import UUID

import numpy as np
import requests
from celery.utils.log import get_task_logger
from PIL import Image
from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.config import settings
from app.database import SyncSessionLocal
from app.models import (
    AttendanceRecord,
    AttendanceSession,
    FaceRecognitionJob,
    StudentFaceEmbedding,
    User,
    UserDeviceToken,
)
from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
from celery_app import celery_app

logger = get_task_logger(__name__)
_BASE_DIR = Path(__file__).resolve().parent.parent.parent
_MEDIA_ROOT = (_BASE_DIR / "app_media").resolve()


def _face_max_image_side() -> int:
    return max(320, int(getattr(settings, "FACE_MAX_IMAGE_SIDE", 1280)))


def _prepare_face_input_image(image_path: str) -> tuple[str, float, float, str | None]:
    """
    Reduz imagens muito grandes para acelerar detecção/embedding no DeepFace.

    Retorna:
    - path a ser usado no DeepFace
    - scale_x / scale_y (para converter facial_area para coordenadas da imagem original)
    - caminho temporário criado (ou None, se não houve resize)
    """

    max_side = _face_max_image_side()
    with Image.open(image_path) as image:
        image = image.convert("RGB")
        orig_w, orig_h = image.size
        longest = max(orig_w, orig_h)
        if longest <= max_side:
            return image_path, 1.0, 1.0, None

        scale = max_side / float(longest)
        new_w = max(1, int(round(orig_w * scale)))
        new_h = max(1, int(round(orig_h * scale)))
        resized = image.resize((new_w, new_h), Image.Resampling.LANCZOS)

        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            resized.save(tmp, format="JPEG", quality=90, optimize=True)
            resized_path = tmp.name

    scale_x = float(orig_w) / float(new_w)
    scale_y = float(orig_h) / float(new_h)
    return resized_path, scale_x, scale_y, resized_path


def _scale_facial_area_to_original(
    facial_area: dict | None,
    *,
    scale_x: float,
    scale_y: float,
) -> dict | None:
    if not facial_area:
        return facial_area
    try:
        return {
            "x": int(round(float(facial_area.get("x", 0)) * scale_x)),
            "y": int(round(float(facial_area.get("y", 0)) * scale_y)),
            "w": int(round(float(facial_area.get("w", 0)) * scale_x)),
            "h": int(round(float(facial_area.get("h", 0)) * scale_y)),
        }
    except Exception:
        return facial_area


def _crop_face_base64(image_path: str, facial_area: dict | None) -> str:
    with Image.open(image_path) as image:
        image = image.convert("RGB")
        if facial_area:
            x = max(int(facial_area.get("x", 0)), 0)
            y = max(int(facial_area.get("y", 0)), 0)
            w = max(int(facial_area.get("w", image.width)), 1)
            h = max(int(facial_area.get("h", image.height)), 1)
            x2 = min(x + w, image.width)
            y2 = min(y + h, image.height)
            if x2 > x and y2 > y:
                image = image.crop((x, y, x2, y2))
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=85)
        return base64.b64encode(buffer.getvalue()).decode("utf-8")


def _classify_match(similarity: float) -> str:
    if similarity >= 0.75:
        return "auto_identified"
    if similarity >= 0.50:
        return "suggestion"
    return "unknown"


def _read_avatar_bytes(avatar_url: str) -> bytes:
    if avatar_url.startswith("http://") or avatar_url.startswith("https://"):
        content = requests.get(avatar_url, timeout=20)
        content.raise_for_status()
        return content.content

    if avatar_url.startswith("/media/"):
        rel = avatar_url[len("/media/") :].lstrip("/")
        media_path = (_MEDIA_ROOT / rel).resolve()
        if _MEDIA_ROOT not in media_path.parents and media_path != _MEDIA_ROOT:
            raise FileNotFoundError("Caminho de mídia inválido para avatar.")
        return media_path.read_bytes()

    raise ValueError("avatar_url inválido para geração de embedding.")


@celery_app.task(bind=True, max_retries=2, time_limit=120)
def process_face_recognition(self, job_id: str) -> None:
    from deepface import DeepFace
    from app.face_model import get_model

    uid = UUID(job_id)
    with SyncSessionLocal() as db:
        job = db.get(FaceRecognitionJob, uid)
        if not job:
            return

        try:
            total_started = time.perf_counter()
            job.status = "processing"
            job.error_message = None
            db.commit()

            load_embeddings_started = time.perf_counter()
            emb_rows = (
                db.execute(
                    select(StudentFaceEmbedding.student_id, StudentFaceEmbedding.embedding).where(
                        StudentFaceEmbedding.academy_id == job.academy_id
                    )
                )
                .all()
            )
            emb_map: dict[UUID, list[float]] = {row[0]: row[1] for row in emb_rows if row[1]}
            students = (
                db.execute(select(User).where(User.id.in_(list(emb_map.keys())))).scalars().all()
                if emb_map
                else []
            )
            student_by_id = {s.id: s for s in students}
            load_embeddings_ms = (time.perf_counter() - load_embeddings_started) * 1000.0

            resize_started = time.perf_counter()
            face_img_path, scale_x, scale_y, resized_tmp_path = _prepare_face_input_image(
                job.photo_path
            )
            resize_ms = (time.perf_counter() - resize_started) * 1000.0

            represent_started = time.perf_counter()
            # Garante que o modelo esteja aquecido no processo antes de representar.
            get_model()
            represented = DeepFace.represent(
                img_path=face_img_path,
                model_name="Facenet512",
                detector_backend="opencv",
                enforce_detection=False,
            )
            represent_ms = (time.perf_counter() - represent_started) * 1000.0
            faces = represented if isinstance(represented, list) else [represented]
            faces = faces[:30]

            known_by_dim: dict[int, tuple[list[UUID], np.ndarray]] = {}
            for sid, embedding in emb_map.items():
                arr = np.asarray(embedding, dtype=np.float32)
                if arr.ndim != 1 or arr.size == 0:
                    continue
                dim = int(arr.size)
                bucket = known_by_dim.get(dim)
                if bucket is None:
                    known_by_dim[dim] = ([sid], np.expand_dims(arr, axis=0))
                else:
                    ids, matrix = bucket
                    ids.append(sid)
                    known_by_dim[dim] = (ids, np.vstack([matrix, arr]))

            for dim, (ids, matrix) in list(known_by_dim.items()):
                norms = np.linalg.norm(matrix, axis=1, keepdims=True)
                normalized = matrix / np.clip(norms, 1e-8, None)
                known_by_dim[dim] = (ids, normalized)

            matching_started = time.perf_counter()
            results: list[dict] = []
            for idx, face in enumerate(faces):
                embedding = face.get("embedding") or []
                arr = np.asarray(embedding, dtype=np.float32)
                if arr.ndim != 1 or arr.size == 0:
                    continue

                best_student: User | None = None
                best_similarity = 0.0
                bucket = known_by_dim.get(int(arr.size))
                if bucket is not None:
                    known_ids, known_matrix = bucket
                    arr = arr / max(float(np.linalg.norm(arr)), 1e-8)
                    similarities = known_matrix @ arr
                    best_idx = int(np.argmax(similarities))
                    best_similarity = max(0.0, min(1.0, float(similarities[best_idx])))
                    best_student = student_by_id.get(known_ids[best_idx])

                status = _classify_match(best_similarity)
                if status == "unknown":
                    best_student = None
                facial_area_raw = face.get("facial_area") if isinstance(face, dict) else None
                facial_area = _scale_facial_area_to_original(
                    facial_area_raw,
                    scale_x=scale_x,
                    scale_y=scale_y,
                )
                results.append(
                    {
                        "face_index": idx,
                        "face_crop_base64": _crop_face_base64(job.photo_path, facial_area),
                        "status": status,
                        "confidence": round(best_similarity, 4),
                        "student": (
                            {
                                "id": str(best_student.id),
                                "name": best_student.name,
                                "avatar_url": best_student.avatar_url,
                                "belt": best_student.graduation,
                            }
                            if best_student
                            else None
                        ),
                    }
                )
            matching_ms = (time.perf_counter() - matching_started) * 1000.0

            payload = {
                "job_id": str(job.id),
                "status": "completed",
                "session_id": str(job.session_id),
                "total_faces_detected": len(results),
                "results": results,
            }
            job.status = "completed"
            job.result_json = payload
            job.completed_at = datetime.now(UTC)
            db.commit()

            # Push ao professor responsável.
            session = db.get(AttendanceSession, job.session_id)
            if (
                session
                and settings.FIREBASE_PROJECT_ID
                and settings.FIREBASE_SERVICE_ACCOUNT_PATH
                and Path(settings.FIREBASE_SERVICE_ACCOUNT_PATH).is_file()
            ):
                tokens = (
                    db.execute(
                        select(UserDeviceToken.fcm_token).where(
                            UserDeviceToken.user_id == session.created_by_user_id
                        )
                    )
                    .scalars()
                    .all()
                )
                if tokens:
                    access_token = asyncio.run(
                        fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
                    )
                    identified = sum(1 for r in results if r.get("status") == "auto_identified")
                    title = "Chamada processada"
                    body = f"{identified} alunos identificados em {(session.title or 'sessão')}. Toque para revisar."
                    for token in tokens:
                        asyncio.run(
                            send_fcm_data_message(
                                project_id=settings.FIREBASE_PROJECT_ID,
                                service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
                                device_token=token,
                                title=title,
                                body=body,
                                access_token=access_token,
                                data={
                                    "type": "face_recognition_complete",
                                    "job_id": str(job.id),
                                    "session_id": str(job.session_id),
                                },
                            )
                        )
            total_ms = (time.perf_counter() - total_started) * 1000.0
            logger.info(
                "Face job concluído",
                extra={
                    "job_id": str(job.id),
                    "academy_id": str(job.academy_id) if job.academy_id else None,
                    "faces": len(results),
                    "known_embeddings": len(emb_map),
                    "resized_input": resized_tmp_path is not None,
                    "load_embeddings_ms": round(load_embeddings_ms, 2),
                    "resize_ms": round(resize_ms, 2),
                    "represent_ms": round(represent_ms, 2),
                    "matching_ms": round(matching_ms, 2),
                    "total_ms": round(total_ms, 2),
                },
            )
        except Exception as exc:
            logger.exception("Falha no processamento facial: %s", exc)
            job = db.get(FaceRecognitionJob, uid)
            if job:
                job.status = "failed"
                job.error_message = str(exc)
                job.completed_at = datetime.now(UTC)
                db.commit()
        finally:
            try:
                if "resized_tmp_path" in locals() and resized_tmp_path:
                    os.remove(resized_tmp_path)
            except OSError:
                pass


@celery_app.task(bind=True, max_retries=2, time_limit=120)
def generate_student_embedding(self, student_id: str) -> None:
    from deepface import DeepFace
    from app.face_model import get_model

    uid = UUID(student_id)
    with SyncSessionLocal() as db:
        user = db.get(User, uid)
        if not user or user.role != "aluno" or not user.academy_id or not user.avatar_url:
            return

        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            tmp_path = tmp.name
            tmp.write(_read_avatar_bytes(user.avatar_url))

        resized_tmp_path: str | None = None
        try:
            face_img_path, _, _, resized_tmp_path = _prepare_face_input_image(tmp_path)
            # Garante que o modelo esteja aquecido no processo antes de representar.
            get_model()
            represented = DeepFace.represent(
                img_path=face_img_path,
                model_name="Facenet512",
                detector_backend="opencv",
                enforce_detection=False,
            )
            faces = represented if isinstance(represented, list) else [represented]
            if not faces:
                return
            embedding = faces[0].get("embedding")
            if not embedding:
                return
            stmt = (
                pg_insert(StudentFaceEmbedding)
                .values(student_id=user.id, academy_id=user.academy_id, embedding=embedding)
                .on_conflict_do_update(
                    index_elements=[StudentFaceEmbedding.student_id],
                    set_={
                        "academy_id": user.academy_id,
                        "embedding": embedding,
                        "updated_at": datetime.now(UTC),
                    },
                )
            )
            db.execute(stmt)
            db.commit()
        finally:
            try:
                os.remove(tmp_path)
            except OSError:
                pass
            try:
                if resized_tmp_path:
                    os.remove(resized_tmp_path)
            except OSError:
                pass


@celery_app.task(bind=True, max_retries=2, time_limit=120)
def cleanup_face_recognition_temp_data(self) -> None:
    now = datetime.now(UTC)
    photo_cutoff = now - timedelta(hours=24)
    jobs_cutoff = now - timedelta(days=7)
    jobs_dir = Path(settings.FACE_JOBS_DIR)

    if jobs_dir.exists():
        for path in jobs_dir.glob("*"):
            try:
                if not path.is_file():
                    continue
                mtime = datetime.fromtimestamp(path.stat().st_mtime, tz=UTC)
                if mtime < photo_cutoff:
                    path.unlink(missing_ok=True)
            except OSError:
                continue

    with SyncSessionLocal() as db:
        old_jobs = (
            db.execute(
                select(FaceRecognitionJob).where(
                    FaceRecognitionJob.status.in_(["completed", "failed"]),
                    FaceRecognitionJob.completed_at.is_not(None),
                    FaceRecognitionJob.completed_at < jobs_cutoff,
                )
            )
            .scalars()
            .all()
        )
        for job in old_jobs:
            if job.photo_path:
                try:
                    Path(job.photo_path).unlink(missing_ok=True)
                except OSError:
                    pass
        db.execute(
            delete(FaceRecognitionJob).where(
                FaceRecognitionJob.status.in_(["completed", "failed"]),
                FaceRecognitionJob.completed_at.is_not(None),
                FaceRecognitionJob.completed_at < jobs_cutoff,
            )
        )
        db.commit()


@celery_app.task(bind=True, max_retries=1, time_limit=120)
def cleanup_expired_sessions(self) -> None:
    """Fecha sessões de presença expiradas para reduzir varreduras em endpoints de listagem."""
    now = datetime.now(UTC)
    with SyncSessionLocal() as db:
        sessions = (
            db.execute(
                select(AttendanceSession).where(
                    AttendanceSession.status == "active",
                    AttendanceSession.expires_at.is_not(None),
                    AttendanceSession.expires_at < now,
                )
            )
            .scalars()
            .all()
        )
        changed = 0
        for session in sessions:
            session.status = "closed"
            session.ends_at = session.ends_at or now
            changed += 1
        if changed:
            db.commit()
