from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class User(Base, UUIDMixin):
    """Usuário do sistema (A-01: vinculado a academia quando informado)."""

    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True, comment="Hash bcrypt da senha para login.")
    name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    points_adjustment: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    graduation: Mapped[str | None] = mapped_column(
        String(32),
        nullable=True,
        index=True,
        comment="Faixa: white, blue, purple, brown, black.",
    )
    role: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="aluno",
        index=True,
        comment="Role: aluno, professor, gerente_academia, administrador, supervisor",
    )
    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    academy: Mapped["Academy | None"] = relationship(
        "Academy",
        back_populates="users",
        lazy="selectin",
    )
    lesson_progresses: Mapped[list["LessonProgress"]] = relationship(
        "LessonProgress",
        back_populates="user",
        lazy="selectin",
    )
    training_feedbacks: Mapped[list["TrainingFeedback"]] = relationship(
        "TrainingFeedback",
        back_populates="user",
        lazy="selectin",
    )
    mission_usages: Mapped[list["MissionUsage"]] = relationship(
        "MissionUsage",
        back_populates="user",
        lazy="selectin",
    )
    technique_executions_as_executor: Mapped[list["TechniqueExecution"]] = relationship(
        "TechniqueExecution",
        foreign_keys="TechniqueExecution.user_id",
        back_populates="user",
        lazy="selectin",
    )
    technique_executions_as_opponent: Mapped[list["TechniqueExecution"]] = relationship(
        "TechniqueExecution",
        foreign_keys="TechniqueExecution.opponent_id",
        back_populates="opponent",
        lazy="selectin",
    )