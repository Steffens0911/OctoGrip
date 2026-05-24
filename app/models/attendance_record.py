from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class AttendanceRecord(Base, UUIDMixin):
    """Presença do aluno registrada em uma sessão."""

    __tablename__ = "attendance_records"

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("attendance_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    checked_in_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    method: Mapped[str] = mapped_column(String(32), nullable=False, default="qr")
    face_recognition: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    added_manually: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        comment="True quando o professor adicionou presença pelo modal manual; QR/scan usam false.",
    )

    session: Mapped[AttendanceSession] = relationship(
        "AttendanceSession",
        back_populates="records",
        lazy="selectin",
    )
    user: Mapped[User] = relationship("User", lazy="selectin")
