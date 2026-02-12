from __future__ import annotations

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class User(Base, UUIDMixin):
    """Usuário do sistema (futuro: autenticação e recomendação)."""

    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Relacionamentos (lazy para não carregar em todo query)
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
