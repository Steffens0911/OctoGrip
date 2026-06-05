from __future__ import annotations

from celery import Celery
from celery.schedules import crontab
from celery.signals import worker_process_init

from app.config import settings

celery_app = Celery(
    "octogrip",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=["app.tasks.face_recognition_tasks", "app.tasks.execution_tasks", "app.tasks.photo_tasks", "app.tasks.at_risk_tasks", "app.tasks.streak_tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    task_time_limit=120,
    task_soft_time_limit=90,
    task_track_started=True,
    broker_connection_retry_on_startup=True,
    # Prefork com concurrency>1 duplica TensorFlow/DeepFace por processo → OOM (SIGKILL) em VPS ~1 GiB.
    # O compose usa --pool=solo (um processo); mantemos 1 aqui para ambientes sem esse flag.
    worker_concurrency=1,
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
        "escalate-pending-executions-to-professor": {
            "task": "app.tasks.execution_tasks.escalate_pending_executions_to_professor",
            "schedule": crontab(hour=4, minute=0),
        },
        "notify-professor-pending-reviews": {
            "task": "app.tasks.execution_tasks.notify_professor_pending_reviews",
            "schedule": crontab(hour=8, minute=0),
        },
        "streak-at-risk-push": {
            "task": "app.tasks.streak_tasks.send_streak_at_risk_push",
            "schedule": crontab(hour=23, minute=0),  # 20h Brasília (UTC-3)
        },
        "weekly-at-risk-alert": {
            "task": "app.tasks.at_risk_tasks.send_weekly_at_risk_alert",
            "schedule": crontab(day_of_week=1, hour=12, minute=0),  # segunda 09h Brasília (UTC-3)
        },
        "expire-photo-restrictions": {
            "task": "app.tasks.photo_tasks.expire_photo_restrictions",
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
