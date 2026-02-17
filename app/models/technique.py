from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Technique(Base, UUIDMixin):
    """Técnica: transição de uma posição para outra. Cada academia tem seu portfólio."""

    __tablename__ = "techniques"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    video_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    base_points: Mapped[int | None] = mapped_column(Integer, nullable=True, default=10)

    from_position_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("positions.id", ondelete="RESTRICT"),
        nullable=False,
    )
    to_position_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("positions.id", ondelete="RESTRICT"),
        nullable=False,
    )

    from_position: Mapped["Position"] = relationship(
        "Position",
        foreign_keys=[from_position_id],
        back_populates="techniques_from",
    )
    to_position: Mapped["Position"] = relationship(
        "Position",
        foreign_keys=[to_position_id],
        back_populates="techniques_to",
    )
    academy: Mapped["Academy"] = relationship(
        "Academy",
        back_populates="techniques",
        foreign_keys=[academy_id],
    )
    lessons: Mapped[list["Lesson"]] = relationship(
        "Lesson",
        back_populates="technique",
        lazy="selectin",
    )
    missions: Mapped[list["Mission"]] = relationship(
        "Mission",
        back_populates="technique",
        lazy="selectin",
    )
    collective_goals: Mapped[list["CollectiveGoal"]] = relationship(
        "CollectiveGoal",
        back_populates="technique",
        lazy="selectin",
    )