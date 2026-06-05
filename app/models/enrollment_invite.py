"""Convite de auto-cadastro e fila de solicitações pendentes por academia."""

from __future__ import annotations

import uuid

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class EnrollmentInvite(Base, UUIDMixin):
    """Token único por academia usado para gerar link/QR de auto-cadastro."""

    __tablename__ = "enrollment_invites"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        unique=True,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    academy = relationship("Academy", foreign_keys=[academy_id])
    pending_enrollments = relationship(
        "PendingEnrollment", back_populates="invite", cascade="all, delete-orphan"
    )


class PendingEnrollment(Base, UUIDMixin):
    """Solicitação de matrícula enviada por aluno via link de convite. Aguarda aprovação."""

    __tablename__ = "pending_enrollments"

    invite_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("enrollment_invites.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    graduation: Mapped[str | None] = mapped_column(String(32), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="pending",
        index=True,
        comment="pending | approved | rejected",
    )
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    invite = relationship("EnrollmentInvite", back_populates="pending_enrollments")
    academy = relationship("Academy", foreign_keys=[academy_id])
