from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class AttendanceSession(Base, UUIDMixin):
    """Sessão de chamada (QR) criada por professor/gestor/admin."""

    __tablename__ = "attendance_sessions"

    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    created_by_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    training_session_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("training_sessions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Treino lançado vinculado a esta chamada (pré-checkin).",
    )
    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="active",
        index=True,
        comment="active|closed",
    )
    title: Mapped[str | None] = mapped_column(Text, nullable=True)
    starts_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    academy: Mapped[Academy | None] = relationship("Academy", lazy="raise")
    created_by: Mapped[User] = relationship("User", lazy="selectin")
    records: Mapped[list[AttendanceRecord]] = relationship(
        "AttendanceRecord",
        back_populates="session",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    training_session: Mapped[TrainingSession | None] = relationship(
        "TrainingSession",
        foreign_keys=[training_session_id],
        lazy="raise",
    )
