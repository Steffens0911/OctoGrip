"""Push notifications de indicação de posição: avisa adversário ao indicar e executor ao confirmar."""

from __future__ import annotations

import logging
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import TechniqueExecution, User
from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
from app.services.push_token_service import list_fcm_tokens_for_user

logger = logging.getLogger(__name__)


def _technique_name(execution: TechniqueExecution) -> str | None:
    """Retorna o nome da técnica via technique, mission ou lesson."""
    if execution.technique and execution.technique.name:
        return execution.technique.name
    if execution.mission and execution.mission.technique and execution.mission.technique.name:
        return execution.mission.technique.name
    if execution.lesson and execution.lesson.technique and execution.lesson.technique.name:
        return execution.lesson.technique.name
    return None


def _user_first_name(user: User | None) -> str:
    if not user:
        return "Um colega"
    name = (user.name or "").strip()
    return name.split()[0] if name else "Um colega"


async def _push(
    db: AsyncSession,
    *,
    to_user_id: UUID,
    title: str,
    body: str,
    data: dict[str, str],
) -> None:
    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        return
    tokens = await list_fcm_tokens_for_user(db, user_id=to_user_id)
    if not tokens:
        return
    try:
        access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    except Exception:
        logger.exception("execution_notification: falha ao obter access token FCM")
        return
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
            logger.info(
                "execution_notification: token inválido descartado",
                extra={"token_prefix": token[:12]},
            )


async def notify_opponent_of_indication(
    db: AsyncSession,
    execution: TechniqueExecution,
) -> None:
    """Push para o adversário quando um aluno indica uma posição para ele confirmar."""
    if not execution.opponent_id:
        return
    executor_name = _user_first_name(execution.user)
    tech = _technique_name(execution)
    body = f"{executor_name} indicou uma posição para você confirmar"
    if tech:
        body = f'{executor_name} indicou "{tech}" para você confirmar'

    await _push(
        db,
        to_user_id=execution.opponent_id,
        title="Nova indicação de posição 🥋",
        body=body,
        data={"type": "execution_indicated", "execution_id": str(execution.id)},
    )
    logger.info(
        "execution_notification: indicação enviada ao adversário",
        extra={"execution_id": str(execution.id), "opponent_id": str(execution.opponent_id)},
    )


async def notify_executor_of_confirmation(
    db: AsyncSession,
    execution: TechniqueExecution,
) -> None:
    """Push para o executor quando o adversário confirma a indicação."""
    if not execution.user_id:
        return
    opponent_name = _user_first_name(execution.opponent)
    tech = _technique_name(execution)
    body = f"{opponent_name} confirmou sua indicação"
    if tech:
        body = f'{opponent_name} confirmou sua indicação de "{tech}"'

    await _push(
        db,
        to_user_id=execution.user_id,
        title="Indicação confirmada! ✅",
        body=body,
        data={"type": "execution_confirmed", "execution_id": str(execution.id)},
    )
    logger.info(
        "execution_notification: confirmação enviada ao executor",
        extra={"execution_id": str(execution.id), "user_id": str(execution.user_id)},
    )


async def notify_executor_of_professor_review(
    db: AsyncSession,
    execution: TechniqueExecution,
    *,
    approved: bool,
) -> None:
    """Push para o executor quando o professor/gerente revisa a indicação escalada."""
    if not execution.user_id:
        return
    tech = _technique_name(execution)
    if approved:
        title = "Indicação aprovada pelo professor! ✅"
        body = "Sua indicação foi aprovada pelo professor e os pontos foram contabilizados"
        if tech:
            body = f'Sua indicação de "{tech}" foi aprovada pelo professor'
        notification_type = "execution_professor_approved"
    else:
        title = "Indicação não confirmada"
        body = "O professor não confirmou sua indicação"
        if tech:
            body = f'O professor não confirmou sua indicação de "{tech}"'
        notification_type = "execution_professor_rejected"

    await _push(
        db,
        to_user_id=execution.user_id,
        title=title,
        body=body,
        data={"type": notification_type, "execution_id": str(execution.id)},
    )
    logger.info(
        "execution_notification: revisão do professor enviada ao executor",
        extra={
            "execution_id": str(execution.id),
            "user_id": str(execution.user_id),
            "approved": approved,
        },
    )
