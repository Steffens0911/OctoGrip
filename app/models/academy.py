"""Academia (B2B): usuário vinculado (A-01), missão por academia (A-02)."""
from __future__ import annotations

from sqlalchemy import String
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
        comment="A-03: tema semanal definido pelo professor; usado na missão do dia.",
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
