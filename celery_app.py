from __future__ import annotations

import os

from celery import Celery
from celery.schedules import crontab
from celery.signals import worker_process_init

from app.config import settings

celery_app = Celery(
    "octogrip",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
    include=[
        "app.tasks.face_recognition_tasks",
        "app.tasks.execution_tasks",
        "app.tasks.photo_tasks",
        "app.tasks.at_risk_tasks",
        "app.tasks.streak_tasks",
        "app.tasks.manual_trophy_tasks",
        "app.tasks.pre_checkin_tasks",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    task_time_limit=120,
    task_soft_time_limit=90,
    task_track_started=True,
    broker_connection_retry_on_startup=True,
    worker_concurrency=1,
    worker_prefetch_multiplier=1,
    task_acks_late=True,
    result_expires=3600,
    timezone="UTC",
    # face_recognition_tasks → fila "face" (worker solo, carrega TensorFlow).
    # Tudo mais → fila "default" (worker prefork leve, sem modelo na RAM).
    task_routes={
        "app.tasks.face_recognition_tasks.*": {"queue": "face"},
        "app.tasks.*": {"queue": "default"},
    },
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
        "pre-checkin-reminder": {
            "task": "app.tasks.pre_checkin_tasks.send_pre_checkin_reminder",
            "schedule": crontab(hour=21, minute=0),  # 18h Brasília (UTC-3)
        },
    },
)


@worker_process_init.connect
def _init_sentry_in_worker(**_: object) -> None:
    """Inicializa Sentry em cada processo worker para capturar exceções de tasks."""
    from app.core.error_tracking import init_sentry
    init_sentry(settings.SENTRY_DSN)


@worker_process_init.connect
def preload_facenet512_model(**_: object) -> None:
    """Pré-carrega o modelo apenas no worker da fila 'face' (FACE_WORKER=1)."""
    if not os.environ.get("FACE_WORKER"):
        return
    try:
        from app.face_model import get_model

        get_model()
    except Exception:
        # Não bloqueia startup do worker; a task falhará com erro explícito se faltar dependência.
        pass
