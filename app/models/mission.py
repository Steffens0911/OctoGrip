from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Mission(Base, UUIDMixin):
    """
    Entrega diária: vincula uma Lesson a um período (start_date..end_date).
    Separa conteúdo (Lesson) da programação da missão do dia.
    Preparado para futura recomendação automática (ex.: algoritmo por progresso/feedback).
    """

    __tablename__ = "missions"

    lesson_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("lessons.id", ondelete="RESTRICT"),
        nullable=False,
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    end_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    level: Mapped[str] = mapped_column(String(32), nullable=False, default="beginner", index=True)

    lesson: Mapped["Lesson"] = relationship(
        "Lesson",
        back_populates="missions",
        lazy="joined",
    )
