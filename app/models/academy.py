"""Academia (B2B): usuário vinculado (A-01), missão por academia (A-02)."""
from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Academy(Base, UUIDMixin):
    """Academia: agrupa usuários e pode ter missões próprias (override global)."""

    __tablename__ = "academies"

    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    slug: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    weekly_theme: Mapped[str | None] = mapped_column(
        String(128),
        nullable=True,
        comment="A-03: tema semanal (legado); preferir weekly_technique_id.",
    )
    weekly_technique_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Técnica slot 1 (seg-ter) ou missão única da semana se 2 e 3 forem null.",
    )
    weekly_technique_2_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Técnica slot 2 (qua-qui).",
    )
    weekly_technique_3_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Técnica slot 3 (sex-dom).",
    )

    weekly_technique: Mapped["Technique | None"] = relationship(
        "Technique",
        foreign_keys=[weekly_technique_id],
        lazy="selectin",
    )
    weekly_technique_2: Mapped["Technique | None"] = relationship(
        "Technique",
        foreign_keys=[weekly_technique_2_id],
        lazy="selectin",
    )
    weekly_technique_3: Mapped["Technique | None"] = relationship(
        "Technique",
        foreign_keys=[weekly_technique_3_id],
        lazy="selectin",
    )
    users: Mapped[list["User"]] = relationship(
        "User",
        back_populates="academy",
        lazy="selectin",
    )
    professors: Mapped[list["Professor"]] = relationship(
        "Professor",
        back_populates="academy",
        lazy="selectin",
    )
    missions: Mapped[list["Mission"]] = relationship(
        "Mission",
        back_populates="academy",
        lazy="selectin",
    )
