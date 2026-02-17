from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Position(Base, UUIDMixin):
    """Posição do jiu-jitsu (ex: guarda fechada, montada). Cada academia tem seu portfólio."""

    __tablename__ = "positions"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    academy: Mapped["Academy"] = relationship("Academy", back_populates="positions")

    # Técnicas que saem desta posição
    techniques_from: Mapped[list["Technique"]] = relationship(
        "Technique",
        foreign_keys="Technique.from_position_id",
        back_populates="from_position",
        lazy="selectin",
    )
    # Técnicas que chegam nesta posição
    techniques_to: Mapped[list["Technique"]] = relationship(
        "Technique",
        foreign_keys="Technique.to_position_id",
        back_populates="to_position",
        lazy="selectin",
    )
    training_feedbacks: Mapped[list["TrainingFeedback"]] = relationship(
        "TrainingFeedback",
        back_populates="position",
        lazy="selectin",
    )
