"""Execução de técnica em adversário (gamificação): aguarda confirmação para pontuar."""
from __future__ import annotations

from datetime import datetime
import uuid

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class TechniqueExecution(Base, UUIDMixin):
    """
    Registro de "aplicou a técnica em alguém". Pontos só contam após o adversário
    confirmar (tentativa correta ou execução com sucesso).
    """

    __tablename__ = "technique_executions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    mission_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("missions.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    lesson_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("lessons.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    technique_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    opponent_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    usage_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="pending_confirmation",
        index=True,
        comment="pending_confirmation | confirmed | rejected | rejected_dont_remember",
    )
    outcome: Mapped[str | None] = mapped_column(String(32), nullable=True)
    points_awarded: Mapped[int | None] = mapped_column(Integer, nullable=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    confirmed_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    user: Mapped["User"] = relationship(
        "User",
        foreign_keys=[user_id],
        back_populates="technique_executions_as_executor",
    )
    mission: Mapped["Mission | None"] = relationship(
        "Mission",
        back_populates="technique_executions",
    )
    lesson: Mapped["Lesson | None"] = relationship(
        "Lesson",
        back_populates="technique_executions",
    )
    technique: Mapped["Technique | None"] = relationship(
        "Technique",
        back_populates="technique_executions_direct",
    )
    opponent: Mapped["User"] = relationship(
        "User",
        foreign_keys=[opponent_id],
        back_populates="technique_executions_as_opponent",
    )
    confirmer: Mapped["User | None"] = relationship(
        "User",
        foreign_keys=[confirmed_by],
    )
