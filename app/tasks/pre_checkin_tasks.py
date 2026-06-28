"""Task Celery: lembrete de pré-checkin para alunos que ainda não confirmaram treinos de amanhã."""

from __future__ import annotations

import asyncio
import logging

from celery_app import celery_app

logger = logging.getLogger(__name__)

_NOTIF_TYPE = "pre_checkin_reminder"


@celery_app.task(bind=True, max_retries=1, time_limit=180)
def send_pre_checkin_reminder(self) -> None:
    """Push para alunos com treinos amanhã que ainda não confirmaram presença."""

    async def _wrapper() -> None:
        from app.database import async_engine

        try:
            await _run()
        finally:
            await async_engine.dispose()

    asyncio.run(_wrapper())


async def _run() -> None:
    from datetime import timedelta

    from sqlalchemy import exists, not_, select

    from app.config import settings
    from app.core.app_time import today_in_app_tz
    from app.database import AsyncSessionLocal
    from app.models.training_pre_checkin import TrainingPreCheckin
    from app.models.training_session import TrainingSession
    from app.models.user import User
    from app.models.user_device_token import UserDeviceToken
    from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
    from app.services.notification_service import create_notification
    from app.services.push_token_service import delete_device_token

    today = today_in_app_tz()
    tomorrow = today + timedelta(days=1)

    async with AsyncSessionLocal() as db:
        # Academias com pré-checkin ativado que têm treinos amanhã
        sessions_result = await db.execute(
            select(TrainingSession)
            .join(TrainingSession.academy)
            .where(
                TrainingSession.class_date == tomorrow,
                TrainingSession.status == "upcoming",
            )
        )
        sessions = list(sessions_result.scalars().all())

        if not sessions:
            return

        # Alunos de cada academia que ainda não confirmaram
        try:
            access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        except Exception:
            logger.exception("pre_checkin_reminder: falha ao obter access token FCM")
            return

        for session in sessions:
            # Alunos da academia que NÃO confirmaram esta sessão
            users_result = await db.execute(
                select(User).where(
                    User.academy_id == session.academy_id,
                    User.role == "aluno",
                    User.account_frozen == False,  # noqa: E712
                    not_(
                        exists(
                            select(TrainingPreCheckin.id).where(
                                TrainingPreCheckin.training_session_id == session.id,
                                TrainingPreCheckin.user_id == User.id,
                                TrainingPreCheckin.status == "confirmed",
                            )
                        )
                    ),
                )
            )
            users = list(users_result.scalars().all())

            label = session.label or "Treino"
            title = f"{label} amanhã às {session.start_time}"
            body = "Confirme sua presença no app para o professor saber quem vem!"

            for user in users:
                await create_notification(
                    db,
                    user_id=user.id,
                    type=_NOTIF_TYPE,
                    title=title,
                    body=body,
                )

                tokens_result = await db.execute(
                    select(UserDeviceToken.fcm_token).where(UserDeviceToken.user_id == user.id)
                )
                tokens = list(tokens_result.scalars().all())

                for token in tokens:
                    success, should_drop = await send_fcm_data_message(
                        project_id=settings.FIREBASE_PROJECT_ID,
                        service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
                        device_token=token,
                        title=title,
                        body=body,
                        access_token=access_token,
                        data={
                            "type": _NOTIF_TYPE,
                            "session_id": str(session.id),
                        },
                    )
                    if should_drop:
                        await delete_device_token(db, fcm_token=token)

        await db.commit()
