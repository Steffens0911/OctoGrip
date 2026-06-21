"""Models para treinos lançados pelo professor e templates (favoritos)."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class TrainingTemplate(Base, UUIDMixin):
    """Treino favorito — template reutilizável para lançar sessões com 1 toque."""

    __tablename__ = "training_templates"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    created_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    label: Mapped[str | None] = mapped_column(String(128), nullable=True)
    start_time: Mapped[str] = mapped_column(
        String(5),
        nullable=False,
        comment="Horário no formato HH:MM (horário de Brasília).",
    )
    tolerance_minutes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=15,
        comment="Tolerância após início para bater presença (minutos).",
    )
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    created_by: Mapped[User | None] = relationship(
        "User",
        foreign_keys=[created_by_user_id],
        lazy="selectin",
    )


class TrainingSession(Base, UUIDMixin):
    """Treino lançado pelo professor para uma data específica."""

    __tablename__ = "training_sessions"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    created_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    template_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("training_templates.id", ondelete="SET NULL"),
        nullable=True,
    )
    class_date: Mapped[date] = mapped_column(Date, nullable=False)
    start_time: Mapped[str] = mapped_column(
        String(5),
        nullable=False,
        comment="Horário no formato HH:MM (horário de Brasília).",
    )
    tolerance_minutes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=15,
        comment="Tolerância após início para bater presença (minutos).",
    )
    label: Mapped[str | None] = mapped_column(String(128), nullable=True)
    status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default="upcoming",
        index=True,
        comment="upcoming | open | closed",
    )
    opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_by: Mapped[User | None] = relationship(
        "User",
        foreign_keys=[created_by_user_id],
        lazy="selectin",
    )
    template: Mapped[TrainingTemplate | None] = relationship(
        "TrainingTemplate",
        foreign_keys=[template_id],
        lazy="selectin",
    )
