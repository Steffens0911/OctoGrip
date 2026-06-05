"""Task Celery: push de streak em risco para alunos que não logaram hoje."""

from __future__ import annotations

import asyncio
import logging
from datetime import date, timedelta

from celery_app import celery_app

logger = logging.getLogger(__name__)

_NOTIF_TYPE = "streak_at_risk"


@celery_app.task(bind=True, max_retries=1, time_limit=180)
def send_streak_at_risk_push(self) -> None:
    """Envia push para alunos com streak ativo que ainda não logaram hoje."""
    asyncio.run(_run())


async def _run() -> None:
    from sqlalchemy import exists, select

    from app.config import settings
    from app.core.app_time import today_in_app_tz
    from app.database import AsyncSessionLocal
    from app.models.user import User
    from app.models.user_device_token import UserDeviceToken
    from app.models.user_login_day import UserLoginDay
    from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
    from app.services.login_streak_service import login_streak_from_distinct_days
    from app.services.push_token_service import delete_device_token

    today: date = today_in_app_tz()
    yesterday: date = today - timedelta(days=1)

    async with AsyncSessionLocal() as db:
        # Alunos que logaram ontem mas NÃO logaram hoje → streak em risco
        logged_yesterday_not_today = (
            await db.execute(
                select(User.id)
                .where(
                    User.role == "aluno",
                    User.account_frozen == False,  # noqa: E712
                    exists(
                        select(UserLoginDay.user_id).where(
                            UserLoginDay.user_id == User.id,
                            UserLoginDay.login_day == yesterday,
                        )
                    ),
                    ~exists(
                        select(UserLoginDay.user_id).where(
                            UserLoginDay.user_id == User.id,
                            UserLoginDay.login_day == today,
                        )
                    ),
                )
            )
        ).scalars().all()

        if not logged_yesterday_not_today:
            return

        try:
            access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        except Exception:
            logger.exception("streak_at_risk: falha ao obter access token FCM")
            return

        for user_id in logged_yesterday_not_today:
            # Calcula o streak atual (baseado em ontem como referência)
            login_days = (
                await db.execute(
                    select(UserLoginDay.login_day)
                    .where(UserLoginDay.user_id == user_id)
                    .order_by(UserLoginDay.login_day.desc())
                    .limit(400)
                )
            ).scalars().all()
            streak = login_streak_from_distinct_days(list(login_days), yesterday)

            if streak < 4:
                continue

            tokens = (
                await db.execute(
                    select(UserDeviceToken.fcm_token).where(
                        UserDeviceToken.user_id == user_id
                    )
                )
            ).scalars().all()

            if not tokens:
                continue

            title = "Seu streak está em risco! 🔥"
            body = f"Você tem {streak} dias seguidos de acesso. Abra o app hoje para não perder!"

            for token in tokens:
                success, should_drop = await send_fcm_data_message(
                    project_id=settings.FIREBASE_PROJECT_ID,
                    service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
                    device_token=token,
                    title=title,
                    body=body,
                    access_token=access_token,
                    data={"type": _NOTIF_TYPE},
                )
                if should_drop:
                    await delete_device_token(db, fcm_token=token)

        await db.commit()
