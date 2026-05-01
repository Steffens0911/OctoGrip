from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, Index, Integer, String

from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin
from app.models.soft_delete import SoftDeleteMixin


class Mission(Base, UUIDMixin, SoftDeleteMixin):
    """
    Missão da academia: vincula uma Técnica a um slot.
    Legado: slot_index 0–2 e weekly_kit_id nulo. Kits semanais: slot_index 0–4 e weekly_kit_id.
    start_date/end_date opcionais (legado).
    """

    __tablename__ = "missions"
    __table_args__ = (
        Index("idx_mission_academy_level_slot_active", "academy_id", "level", "slot_index", "is_active"),
    )

    technique_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("techniques.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    lesson_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("lessons.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Lição da missão; quando preenchido, missão = esta lição no período.",
    )
    slot_index: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        index=True,
        comment="Slot da academia: 0–2 sem kit; 0–4 com weekly_kit_id. NULL para missões globais/legado.",
    )
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    level: Mapped[str] = mapped_column(String(32), nullable=False, default="beginner", index=True)
    theme: Mapped[str | None] = mapped_column(String(128), nullable=True)
    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
        comment="NULL = missão global; preenchido = override da academia (A-02).",
    )
    weekly_kit_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("weekly_technique_kits.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
        comment="NULL = missão do slot legado (0–2); preenchido = missão de kit semanal (slot 0–4).",
    )
    multiplier: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=10,
        comment="Pontos fixos ao concluir a missão (10–50).",
    )

    academy: Mapped["Academy | None"] = relationship(
        "Academy",
        back_populates="missions",
        lazy="raise",
    )
    weekly_kit: Mapped["WeeklyTechniqueKit | None"] = relationship(
        "WeeklyTechniqueKit",
        lazy="selectin",
    )
    technique: Mapped["Technique"] = relationship(
        "Technique",
        back_populates="missions",
        lazy="joined",
    )
    lesson: Mapped["Lesson | None"] = relationship(
        "Lesson",
        back_populates="missions",
        lazy="joined",
    )
    mission_usages: Mapped[list["MissionUsage"]] = relationship(
        "MissionUsage",
        back_populates="mission",
        lazy="raise",
    )
    technique_executions: Mapped[list["TechniqueExecution"]] = relationship(
        "TechniqueExecution",
        back_populates="mission",
        lazy="raise",
    )

    @property
    def technique_name(self) -> str | None:
        return self.technique.name if self.technique else None