"""Registo de token FCM para o utilizador autenticado."""

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.database import get_db
from app.models import User, UserDeviceToken
from app.schemas.push_notification import PushTokenRegister
from app.services.push_token_service import upsert_device_token

router = APIRouter()


@router.post("/push_token", status_code=status.HTTP_204_NO_CONTENT)
async def register_my_push_token(
    body: PushTokenRegister,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Associa o token FCM do dispositivo ao utilizador logado (Android/iOS/Web com suporte)."""
    await upsert_device_token(
        db,
        user_id=current_user.id,
        fcm_token=body.token,
        platform=body.platform,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/push_tokens", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_all_my_push_tokens(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Remove todos os tokens FCM do utilizador (ex.: logout)."""
    await db.execute(delete(UserDeviceToken).where(UserDeviceToken.user_id == current_user.id))
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
