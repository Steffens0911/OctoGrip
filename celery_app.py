from __future__ import annotations

from celery import Celery
from celery.schedules import crontab
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
    task_soft_time_limit=90,
    task_track_started=True,
    broker_connection_retry_on_startup=True,
    worker_concurrency=2,
    worker_prefetch_multiplier=1,
    task_acks_late=True,
    result_expires=3600,
    timezone="UTC",
    beat_schedule={
        "face-recognition-cleanup-daily": {
            "task": "app.tasks.face_recognition_tasks.cleanup_face_recognition_temp_data",
            "schedule": crontab(hour=3, minute=0),
        },
        "cleanup-expired-attendance-sessions": {
            "task": "app.tasks.face_recognition_tasks.cleanup_expired_sessions",
            "schedule": crontab(minute="*/30"),
        },
    },
)


@worker_process_init.connect
def preload_facenet512_model(**_: object) -> None:
    """Pré-carrega o modelo no processo worker para reduzir cold start da primeira task."""
    try:
        from app.face_model import get_model

        get_model()
    except Exception:
        # Não bloqueia startup do worker; a task falhará com erro explícito se faltar dependência.
        pass
