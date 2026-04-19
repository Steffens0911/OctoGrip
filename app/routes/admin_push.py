"""Broadcast de notificações push (FCM) para administradores da plataforma."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.core.exceptions import AppError
from app.core.role_deps import require_admin
from app.models import User
from app.schemas.push_notification import AcademyPushNotifyRequest, AcademyPushNotifyResponse
from app.services.fcm_service import send_fcm_data_message
from app.services.push_token_service import delete_device_token, list_all_fcm_tokens

router = APIRouter()


@router.post("/push_broadcast", response_model=AcademyPushNotifyResponse)
async def admin_push_broadcast(
    body: AcademyPushNotifyRequest,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),  # autorização apenas
):
    """
    Envia push a **todos** os dispositivos com token FCM na base (quem abriu a app,
    fez login e aceitou notificações). Apenas role `administrador`.
    """
    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        raise AppError(
            "Notificações push não estão configuradas (FIREBASE_PROJECT_ID e "
            "FIREBASE_SERVICE_ACCOUNT_PATH no servidor).",
            status_code=503,
        )

    tokens = await list_all_fcm_tokens(db)
    if not tokens:
        return AcademyPushNotifyResponse(target_tokens=0, sent=0, failed=0)

    sent = 0
    failed = 0
    for device_token in tokens:
        ok, drop = await send_fcm_data_message(
            project_id=settings.FIREBASE_PROJECT_ID,
            service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
            device_token=device_token,
            title=body.title.strip(),
            body=body.body.strip(),
        )
        if ok:
            sent += 1
        else:
            failed += 1
            if drop:
                await delete_device_token(db, fcm_token=device_token)

    return AcademyPushNotifyResponse(
        target_tokens=len(tokens),
        sent=sent,
        failed=failed,
    )
