"""Modelo de consentimento LGPD (registro append-only).

Cada concessão ou revogação de consentimento gera uma nova linha. O estado atual de
um par (user, consent_type) é sempre a linha mais recente por ``created_at``. Isso
mantém uma trilha de auditoria imutável — exigência prática para comprovar
consentimento perante a ANPD (LGPD, art. 8º).
"""

from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin

if TYPE_CHECKING:
    from app.models.user import User

# Tipos de consentimento rastreados.
#   terms     — aceite dos Termos de Uso
#   privacy   — aceite da Política de Privacidade
#   biometric — consentimento específico para tratamento de dado biométrico facial
CONSENT_TYPES = ("terms", "privacy", "biometric")


class UserConsent(Base, UUIDMixin):
    """Linha de consentimento (append-only)."""

    __tablename__ = "user_consents"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    consent_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        index=True,
        comment="terms | privacy | biometric",
    )
    granted: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        comment="True = concedido; False = revogado.",
    )
    document_version: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
        comment="Versão do documento aceito (ex.: 2026-06-13).",
    )
    ip_address: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
        comment="IP de origem no momento do registro (prova de consentimento).",
    )
    user_agent: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="User-Agent de origem no momento do registro.",
    )

    user: Mapped[User] = relationship("User", lazy="raise")
