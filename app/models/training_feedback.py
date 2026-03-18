from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class TrainingFeedback(Base, UUIDMixin):
    """Registro de dificuldade do usuário no treino (sem vínculo com Position)."""

    __tablename__ = "training_feedback"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    difficulty_level: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Escala 1-5, onde 5 = muita dificuldade",
    )
    note: Mapped[str | None] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship("User", back_populates="training_feedbacks")
