from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Technique(Base, UUIDMixin):
    """Técnica: transição de uma posição para outra."""

    __tablename__ = "techniques"

    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

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
