"""Task Celery: notificações de concessão de troféu manual."""

from __future__ import annotations

import asyncio
import logging
from uuid import UUID

from celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=1, time_limit=120)
def notify_manual_trophy_awarded(self, award_id: str) -> None:
    """Envia notificações in-app e push para concessão de troféu manual."""
    asyncio.run(_run(UUID(award_id)))


async def _run(award_id: UUID) -> None:
    from sqlalchemy import select

    from app.config import settings
    from app.database import AsyncSessionLocal
    from app.models.manual_trophy import AcademyTrophyAward, AcademyTrophyTemplate
    from app.models.user import User
    from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
    from app.services.notification_service import create_notification, create_notifications_for_academy_students
    from app.services.push_token_service import list_fcm_tokens_for_academy, list_fcm_tokens_for_user

    async with AsyncSessionLocal() as db:
        award = (
            await db.execute(
                select(AcademyTrophyAward)
                .where(AcademyTrophyAward.id == award_id)
            )
        ).scalar_one_or_none()
        if not award:
            logger.warning("notify_manual_trophy_awarded: award não encontrado", extra={"award_id": str(award_id)})
            return

        template = (
            await db.execute(
                select(AcademyTrophyTemplate).where(AcademyTrophyTemplate.id == award.template_id)
            )
        ).scalar_one_or_none()
        if not template:
            return

        user = (await db.execute(select(User).where(User.id == award.user_id))).scalar_one_or_none()
        if not user:
            return

        kind_label = "Medalha" if template.trophy_type == "championship" else "Troféu"
        _tier_labels = {"gold": "Ouro 🥇", "silver": "Prata 🥈", "bronze": "Bronze 🥉", "participation": "Participação 🎖️"}
        tier_label = _tier_labels.get(award.medal_type or "", "🏆")
        title = f"{kind_label} concedido! {tier_label}"
        body = template.name
        notif_data = {"type": "manual_trophy_awarded", "award_id": str(award.id)}

        # Notificação in-app pessoal
        await create_notification(
            db,
            user_id=award.user_id,
            type="manual_trophy_awarded",
            title=title,
            body=body,
            data=notif_data,
        )

        # Notificação social (academia toda)
        user_name = (user.name or "Um aluno").strip()
        if user.academy_id:
            await create_notifications_for_academy_students(
                db,
                academy_id=user.academy_id,
                type="trophy_social",
                title=f"{user_name} recebeu {kind_label}! {tier_label}",
                body=body,
                data=notif_data,
                exclude_user_id=award.user_id,
            )

        # Push FCM
        if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
            return
        try:
            access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        except Exception:
            logger.exception("manual_trophy: falha ao obter FCM access token")
            return

        push_data = {"type": "manual_trophy_awarded", "award_id": str(award.id)}
        personal_tokens = await list_fcm_tokens_for_user(db, user_id=award.user_id)
        for token in personal_tokens:
            await send_fcm_data_message(
                project_id=settings.FIREBASE_PROJECT_ID,
                service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
                device_token=token,
                title=title,
                body=body,
                access_token=access_token,
                data=push_data,
            )

        if user.academy_id:
            personal_set = set(personal_tokens)
            academy_tokens = await list_fcm_tokens_for_academy(db, academy_id=user.academy_id)
            social_tokens = [t for t in academy_tokens if t not in personal_set]
            social_title = f"{user_name} recebeu {kind_label}! {tier_label}"
            for token in social_tokens:
                await send_fcm_data_message(
                    project_id=settings.FIREBASE_PROJECT_ID,
                    service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
                    device_token=token,
                    title=social_title,
                    body=body,
                    access_token=access_token,
                    data=push_data,
                )
