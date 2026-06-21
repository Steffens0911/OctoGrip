"""Model para confirmação antecipada de presença (pré-checkin)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class TrainingPreCheckin(Base, UUIDMixin):
    """Confirmação antecipada do aluno para um treino."""

    __tablename__ = "training_pre_checkins"
    __table_args__ = (UniqueConstraint("training_session_id", "user_id", name="uq_pre_checkin_session_user"),)

    training_session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("training_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="confirmed",
        comment="confirmed | cancelled",
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship("User", foreign_keys=[user_id], lazy="selectin")
    session: Mapped[TrainingSession] = relationship(
        "TrainingSession", foreign_keys=[training_session_id], lazy="raise"
    )
