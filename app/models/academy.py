"""Academia (B2B): usuário vinculado (A-01), missão por academia (A-02)."""
from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String
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
        ForeignKey("techniques.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Técnica slot 1 (seg-ter) ou missão única da semana se 2 e 3 forem null.",
    )
    weekly_technique_2_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Técnica slot 2 (qua-qui).",
    )
    weekly_technique_3_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Técnica slot 3 (sex-dom).",
    )
    visible_lesson_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("lessons.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Lição em destaque visível para os alunos da academia.",
    )
    weekly_multiplier_1: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    weekly_multiplier_2: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    weekly_multiplier_3: Mapped[int] = mapped_column(Integer, nullable=False, default=1)

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
    visible_lesson: Mapped["Lesson | None"] = relationship(
        "Lesson",
        foreign_keys=[visible_lesson_id],
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
    collective_goals: Mapped[list["CollectiveGoal"]] = relationship(
        "CollectiveGoal",
        back_populates="academy",
        lazy="selectin",
    )
    positions: Mapped[list["Position"]] = relationship(
        "Position",
        back_populates="academy",
        lazy="selectin",
    )
    techniques: Mapped[list["Technique"]] = relationship(
        "Technique",
        back_populates="academy",
        foreign_keys="Technique.academy_id",
        lazy="selectin",
    )
    trophies: Mapped[list["Trophy"]] = relationship(
        "Trophy",
        back_populates="academy",
        lazy="selectin",
    )