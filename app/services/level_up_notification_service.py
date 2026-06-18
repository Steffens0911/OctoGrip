"""Notifica o aluno quando sobe de nível (level-up): notificação in-app + push FCM."""

from __future__ import annotations

import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import User
from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
from app.services.notification_service import create_notification
from app.services.push_token_service import list_fcm_tokens_for_user

logger = logging.getLogger(__name__)

NOTIFICATION_TYPE = "level_up"


def _level_up_title(new_level: int) -> str:
    return f"Nível {new_level} alcançado! 🎉"


def _level_up_body(new_level: int) -> str:
    return f"Você subiu para o nível {new_level}. Continue treinando para chegar ainda mais longe!"


async def _send_level_up_push(db: AsyncSession, user_id: UUID, new_level: int, *, title: str, body: str) -> None:
    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        return

    tokens = await list_fcm_tokens_for_user(db, user_id=user_id)
    if not tokens:
        return

    try:
        access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    except Exception:
        logger.exception("level_up_notification: falha ao obter access token FCM")
        return

    data = {"type": NOTIFICATION_TYPE, "level": str(new_level)}
    for token in tokens:
        _, drop = await send_fcm_data_message(
            project_id=settings.FIREBASE_PROJECT_ID,
            service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
            device_token=token,
            title=title,
            body=body,
            access_token=access_token,
            data=data,
        )
        if drop:
            logger.info("level_up_notification: token inválido descartado", extra={"token_prefix": token[:12]})


async def notify_level_up(db: AsyncSession, *, user_id: UUID, new_level: int) -> None:
    """Cria a notificação in-app e envia push para o aluno que acabou de subir de nível.

    Pensado para ser chamado fire-and-forget logo após `refresh_user_level` detectar
    um aumento de nível; nunca deve interromper o fluxo de pontuação.
    """
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        return

    title = _level_up_title(new_level)
    body = _level_up_body(new_level)

    await create_notification(
        db,
        user_id=user_id,
        type=NOTIFICATION_TYPE,
        title=title,
        body=body,
        data={"level": str(new_level)},
    )

    logger.info(
        "level_up_notification: nível alcançado",
        extra={"user_id": str(user_id), "new_level": new_level},
    )

    await _send_level_up_push(db, user_id, new_level, title=title, body=body)
