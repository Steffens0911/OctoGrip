"""Meta coletiva semanal por técnica (gamificação)."""
from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import Date, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class CollectiveGoal(Base, UUIDMixin):
    """Meta de execuções (ex.: 100 escape da montada na semana)."""

    __tablename__ = "collective_goals"

    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    technique_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("techniques.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    target_count: Mapped[int] = mapped_column(Integer, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)

    academy: Mapped["Academy | None"] = relationship("Academy", back_populates="collective_goals")
    technique: Mapped["Technique"] = relationship("Technique", back_populates="collective_goals")
