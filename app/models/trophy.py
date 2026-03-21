"""Troféu por academia: meta de execuções de uma técnica em período; tiers ouro/prata/bronze pela faixa do adversário."""
from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Trophy(Base, UUIDMixin):
    """
    Troféu criado pela academia: nome (ex. Arm Lock), técnica, período e meta de execuções.
    O usuário conquista ouro/prata/bronze conforme a faixa dos adversários nas execuções confirmadas.
    """

    __tablename__ = "trophies"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    technique_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("techniques.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    target_count: Mapped[int] = mapped_column(Integer, nullable=False)
    award_kind: Mapped[str] = mapped_column(String(32), nullable=False, default="trophy", index=True)
    min_duration_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    min_points_to_unlock: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    min_graduation_to_unlock: Mapped[str | None] = mapped_column(String(32), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    academy: Mapped["Academy"] = relationship(
        "Academy",
        back_populates="trophies",
        lazy="selectin",
    )
    technique: Mapped["Technique"] = relationship(
        "Technique",
        back_populates="trophies",
        lazy="joined",
    )
