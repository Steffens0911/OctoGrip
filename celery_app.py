from __future__ import annotations

from celery import Celery
from celery.signals import worker_process_init

from app.config import settings

celery_app = Celery(
    "octogrip",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=["app.tasks.face_recognition_tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    task_time_limit=120,
    task_track_started=True,
    broker_connection_retry_on_startup=True,
    timezone="UTC",
    beat_schedule={
        "face-recognition-cleanup-daily": {
            "task": "app.tasks.face_recognition_tasks.cleanup_face_recognition_temp_data",
            "schedule": 24 * 60 * 60,
        }
    },
)


@worker_process_init.connect
def preload_arcface_model(**_: object) -> None:
    """Pré-carrega o modelo no processo worker para reduzir cold start da primeira task."""
    try:
        from deepface import DeepFace

        DeepFace.build_model("ArcFace")
    except Exception:
        # Não bloqueia startup do worker; a task falhará com erro explícito se faltar dependência.
        pass
