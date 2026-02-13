"""Registro de uso da missão (sync do app): antes/depois do treino (PB-01)."""
from __future__ import annotations

from datetime import datetime
import uuid

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class MissionUsage(Base, UUIDMixin):
    """
    Uso de missão por usuário: abertura, conclusão e momento (before_training / after_training).
    Sincronizado pelo app (PB-01). Base para métricas de retenção (PB-02) e histórico (PB-03).
    """

    __tablename__ = "mission_usages"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    lesson_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("lessons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    opened_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    usage_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        comment="before_training | after_training",
    )

    user: Mapped["User"] = relationship("User", back_populates="mission_usages")
    lesson: Mapped["Lesson"] = relationship("Lesson", back_populates="mission_usages")
