"""Direitos do titular (LGPD, art. 18): acesso/portabilidade e eliminação.

A eliminação é implementada como **anonimização**: removemos os dados que identificam
a pessoa (nome, e-mail, senha, avatar, biometria) e preservamos registros históricos
de forma de-identificada (pontos, presenças, execuções). A LGPD admite a anonimização
como alternativa à exclusão (art. 12) e isso mantém a integridade referencial das
estatísticas da academia.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    StudentFaceEmbedding,
    TechniqueExecution,
    User,
    UserConsent,
    UserDeviceToken,
    UserLoginDay,
    UserTrophyEarned,
)
from app.services import consent_service

logger = logging.getLogger(__name__)


async def _count(db: AsyncSession, stmt) -> int:
    return int((await db.execute(stmt)).scalar() or 0)


async def export_user_data(db: AsyncSession, user: User) -> dict:
    """Monta a cópia dos dados pessoais do titular."""
    consent_rows = (
        (
            await db.execute(
                select(UserConsent).where(UserConsent.user_id == user.id).order_by(UserConsent.created_at.desc())
            )
        )
        .scalars()
        .all()
    )
    consents = [
        {
            "consent_type": c.consent_type,
            "granted": c.granted,
            "document_version": c.document_version,
            "recorded_at": c.created_at.isoformat() if c.created_at else None,
        }
        for c in consent_rows
    ]

    has_biometric = await _count(
        db, select(func.count()).select_from(StudentFaceEmbedding).where(StudentFaceEmbedding.student_id == user.id)
    )
    device_tokens = await _count(
        db, select(func.count()).select_from(UserDeviceToken).where(UserDeviceToken.user_id == user.id)
    )
    login_days = await _count(db, select(func.count()).select_from(UserLoginDay).where(UserLoginDay.user_id == user.id))
    executions = await _count(
        db, select(func.count()).select_from(TechniqueExecution).where(TechniqueExecution.user_id == user.id)
    )
    trophies = await _count(
        db, select(func.count()).select_from(UserTrophyEarned).where(UserTrophyEarned.user_id == user.id)
    )

    return {
        "generated_at": datetime.now(UTC),
        "profile": {
            "id": str(user.id),
            "email": user.email,
            "name": user.name,
            "role": user.role,
            "graduation": user.graduation,
            "academy_id": str(user.academy_id) if user.academy_id else None,
            "reward_level": user.reward_level,
            "reward_level_points": user.reward_level_points,
            "has_avatar": bool(user.avatar_url),
            "has_facial_photo": bool(user.facial_photo_url),
            "created_at": user.created_at.isoformat() if user.created_at else None,
            "last_login_at": user.last_login_at.isoformat() if user.last_login_at else None,
        },
        "consents": consents,
        "related_data": {
            "has_biometric_embedding": bool(has_biometric),
            "device_tokens": device_tokens,
            "login_days": login_days,
            "technique_executions": executions,
            "trophies_earned": trophies,
        },
    }


async def anonymize_user(db: AsyncSession, user: User) -> None:
    """Anonimiza o titular: remove identificadores e dado biométrico; preserva histórico de-identificado."""
    # Purga dado biométrico (embedding + foto facial).
    await consent_service.purge_biometric_data(db, user, commit=False)

    # Remove tokens de push (deixar de notificar e de rastrear o dispositivo).
    await db.execute(delete(UserDeviceToken).where(UserDeviceToken.user_id == user.id))

    # Anonimiza identificadores diretos.
    user.email = f"removido-{uuid4().hex}@anonimizado.invalid"
    user.name = "Usuário removido"
    user.password_hash = None
    user.avatar_url = None
    user.account_frozen = True
    user.account_freeze_reason = "Conta anonimizada a pedido do titular (LGPD, art. 18)."

    # Registra revogação de todos os consentimentos como trilha de auditoria.
    for consent_type in ("terms", "privacy", "biometric"):
        await consent_service.record_consent(
            db,
            user_id=user.id,
            consent_type=consent_type,
            granted=False,
            commit=False,
        )

    await db.commit()
    logger.info(
        "Conta anonimizada (direito de eliminação)",
        extra={"event_type": "account_anonymized", "user_id": str(user.id)},
    )
