"""Parceiro da academia: divulgação para alunos (nome, descrição, link)."""
from __future__ import annotations

import uuid

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Partner(Base, UUIDMixin):
    """Parceiro vinculado a uma academia (ex.: empresa, outra academia)."""

    __tablename__ = "partners"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    highlight_on_login: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default="false",
    )

    academy: Mapped["Academy"] = relationship("Academy", back_populates="partners")
