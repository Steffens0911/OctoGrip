"""Denúncias de conteúdo e bloqueio de usuários no feed de fotos (OctoPhotos).

Exigência da política de conteúdo gerado por usuário da Google Play: o app precisa de um meio
dentro dele para denunciar conteúdo e usuários e para bloquear usuários abusivos.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, Text, func, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.models.base import UUIDMixin

REPORT_REASONS = ("spam", "nudity", "violence", "harassment", "other")
REPORT_STATUSES = ("open", "removed", "dismissed")


class AcademyPhotoReport(Base, UUIDMixin):
    """Denúncia de um post (``comment_id`` nulo) ou de um comentário de um post."""

    __tablename__ = "academy_photo_reports"
    __table_args__ = (
        # Uma denúncia por pessoa e por alvo (denunciar de novo não duplica).
        Index(
            "ux_photo_reports_photo",
            "reporter_id",
            "photo_id",
            unique=True,
            postgresql_where=text("comment_id IS NULL"),
        ),
        Index(
            "ux_photo_reports_comment",
            "reporter_id",
            "comment_id",
            unique=True,
            postgresql_where=text("comment_id IS NOT NULL"),
        ),
        Index("ix_photo_reports_academy_status", "academy_id", "status", "created_at"),
    )

    academy_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("academies.id", ondelete="CASCADE"), nullable=False
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    photo_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("academy_photos.id", ondelete="CASCADE"), nullable=False
    )
    comment_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("academy_photo_comments.id", ondelete="CASCADE"), nullable=True
    )
    reason: Mapped[str] = mapped_column(String(20), nullable=False)
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="open", server_default="open")
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class UserBlock(Base):
    """``blocker_id`` não vê mais posts nem comentários de ``blocked_id`` (bloqueio de mão única)."""

    __tablename__ = "user_blocks"
    __table_args__ = (CheckConstraint("blocker_id <> blocked_id", name="ck_user_blocks_not_self"),)

    blocker_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    blocked_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
