"""Professor: responsável por uma academia (área do professor)."""
from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Professor(Base, UUIDMixin):
    """Professor vinculado a uma academia (painel professor: missões, tema, ranking)."""

    __tablename__ = "professors"

    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    academy: Mapped["Academy | None"] = relationship(
        "Academy",
        back_populates="professors",
        lazy="selectin",
    )
