from __future__ import annotations

import asyncio
import base64
import io
import os
import tempfile
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


def _cosine_similarity(a: list[float], b: list[float]) -> float:
    va = np.array(a, dtype=np.float32)
    vb = np.array(b, dtype=np.float32)
    denom = (np.linalg.norm(va) * np.linalg.norm(vb)) + 1e-8
    sim = float(np.dot(va, vb) / denom)
    return max(0.0, min(1.0, sim))


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


@celery_app.task(bind=True, max_retries=2, time_limit=120)
def process_face_recognition(self, job_id: str) -> None:
    from deepface import DeepFace

    uid = UUID(job_id)
    with SyncSessionLocal() as db:
        job = db.get(FaceRecognitionJob, uid)
        if not job:
            return

        try:
            job.status = "processing"
            job.error_message = None
            db.commit()

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

            represented = DeepFace.represent(
                img_path=job.photo_path,
                model_name="ArcFace",
                detector_backend="retinaface",
                enforce_detection=False,
            )
            faces = represented if isinstance(represented, list) else [represented]
            faces = faces[:30]

            results: list[dict] = []
            for idx, face in enumerate(faces):
                embedding = face.get("embedding") or []
                if not embedding:
                    continue
                best_student: User | None = None
                best_similarity = 0.0
                for sid, known_embedding in emb_map.items():
                    sim = _cosine_similarity(embedding, known_embedding)
                    if sim > best_similarity:
                        best_similarity = sim
                        best_student = student_by_id.get(sid)

                status = _classify_match(best_similarity)
                if status == "unknown":
                    best_student = None
                facial_area = face.get("facial_area") if isinstance(face, dict) else None
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
        except Exception as exc:
            logger.exception("Falha no processamento facial: %s", exc)
            job = db.get(FaceRecognitionJob, uid)
            if job:
                job.status = "failed"
                job.error_message = str(exc)
                job.completed_at = datetime.now(UTC)
                db.commit()


@celery_app.task(bind=True, max_retries=2, time_limit=120)
def generate_student_embedding(self, student_id: str) -> None:
    from deepface import DeepFace

    uid = UUID(student_id)
    with SyncSessionLocal() as db:
        user = db.get(User, uid)
        if not user or user.role != "aluno" or not user.academy_id or not user.avatar_url:
            return

        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            tmp_path = tmp.name
            content = requests.get(user.avatar_url, timeout=20)
            content.raise_for_status()
            tmp.write(content.content)

        try:
            represented = DeepFace.represent(
                img_path=tmp_path,
                model_name="ArcFace",
                detector_backend="retinaface",
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
