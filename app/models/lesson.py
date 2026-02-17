from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Lesson(Base, UUIDMixin):
    """Aula vinculada a uma técnica (conteúdo de estudo). academy_id derivado da técnica."""

    __tablename__ = "lessons"

    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    slug: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    video_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    base_points: Mapped[int | None] = mapped_column(Integer, nullable=True, default=10)

    technique_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("techniques.id", ondelete="RESTRICT"),
        nullable=False,
    )

    technique: Mapped["Technique"] = relationship(
        "Technique",
        back_populates="lessons",
    )
    academy: Mapped["Academy | None"] = relationship(
        "Academy",
        foreign_keys=[academy_id],
        lazy="selectin",
    )
    missions: Mapped[list["Mission"]] = relationship(
        "Mission",
        back_populates="lesson",
        lazy="selectin",
    )

    @property
    def technique_name(self) -> str | None:
        return self.technique.name if self.technique else None

    @property
    def position_name(self) -> str | None:
        if not self.technique or not self.technique.from_position or not self.technique.to_position:
            return None
        return f"da posição {self.technique.from_position.name} → para posição {self.technique.to_position.name}"

    @property
    def technique_video_url(self) -> str | None:
        """Vídeo da técnica, usado como fallback quando a lição não tem video_url."""
        if not self.technique or not self.technique.video_url or not self.technique.video_url.strip():
            return None
        return self.technique.video_url.strip()
    lesson_progresses: Mapped[list["LessonProgress"]] = relationship(
        "LessonProgress",
        back_populates="lesson",
        lazy="selectin",
    )
    mission_usages: Mapped[list["MissionUsage"]] = relationship(
        "MissionUsage",
        back_populates="lesson",
        lazy="selectin",
    )
    technique_executions: Mapped[list["TechniqueExecution"]] = relationship(
        "TechniqueExecution",
        back_populates="lesson",
        lazy="selectin",
    )