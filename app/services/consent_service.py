"""Lógica de consentimento LGPD e purga de dado biométrico.

Centraliza o registro append-only de consentimentos e a remoção do dado biométrico
quando o titular revoga. Rotas e tasks devem chamar estas funções em vez de
manipular as tabelas diretamente.
"""

from __future__ import annotations

import logging
import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import StudentFaceEmbedding, User, UserConsent

logger = logging.getLogger(__name__)

_VERSION_BY_TYPE: dict[str, str] = {
    "terms": settings.LEGAL_TERMS_VERSION,
    "privacy": settings.LEGAL_PRIVACY_VERSION,
    "biometric": settings.LEGAL_BIOMETRIC_VERSION,
}


def current_version_for(consent_type: str) -> str | None:
    """Versão vigente do documento associado ao tipo de consentimento."""
    return _VERSION_BY_TYPE.get(consent_type)


async def record_consent(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    consent_type: str,
    granted: bool,
    document_version: str | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
    commit: bool = True,
) -> UserConsent:
    """Insere uma nova linha de consentimento (concessão ou revogação)."""
    row = UserConsent(
        user_id=user_id,
        consent_type=consent_type,
        granted=granted,
        document_version=document_version or current_version_for(consent_type),
        ip_address=ip_address,
        user_agent=user_agent,
    )
    db.add(row)
    if commit:
        await db.commit()
        await db.refresh(row)
    return row


async def get_current_consents(db: AsyncSession, user_id: uuid.UUID) -> dict[str, UserConsent]:
    """Retorna a linha mais recente por tipo de consentimento para o utilizador."""
    rows = (
        (
            await db.execute(
                select(UserConsent).where(UserConsent.user_id == user_id).order_by(UserConsent.created_at.desc())
            )
        )
        .scalars()
        .all()
    )
    latest: dict[str, UserConsent] = {}
    for row in rows:
        # Primeira ocorrência por tipo == mais recente (lista já vem desc).
        latest.setdefault(row.consent_type, row)
    return latest


async def has_active_biometric_consent(db: AsyncSession, user_id: uuid.UUID) -> bool:
    """True se o titular tem consentimento biométrico vigente (última linha = concedido)."""
    current = await get_current_consents(db, user_id)
    row = current.get("biometric")
    return bool(row and row.granted)


async def purge_biometric_data(db: AsyncSession, user: User, *, commit: bool = True) -> None:
    """Remove todo o dado biométrico do titular: embedding facial e foto facial de origem."""
    await db.execute(delete(StudentFaceEmbedding).where(StudentFaceEmbedding.student_id == user.id))
    if user.facial_photo_url:
        user.facial_photo_url = None
    if commit:
        await db.commit()
    logger.info(
        "Dado biométrico purgado",
        extra={"event_type": "biometric_data_purged", "user_id": str(user.id)},
    )
