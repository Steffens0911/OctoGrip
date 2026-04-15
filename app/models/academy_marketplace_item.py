from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin

if TYPE_CHECKING:
    from app.models.academy import Academy
    from app.models.user import User


class AcademyMarketplaceItem(Base, UUIDMixin):
    """Anúncio de produto no marketplace da academia (divulgação; contato via WhatsApp)."""

    __tablename__ = "academy_marketplace_items"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    currency: Mapped[str] = mapped_column(String(8), nullable=False, default="BRL")
    image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    whatsapp_phone: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="Dígitos E164 BR (ex.: 5511999999999); NULL = anúncio sem WhatsApp.",
    )
    sort_order: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    academy: Mapped[Academy] = relationship(
        "Academy",
        back_populates="marketplace_items",
        lazy="selectin",
    )
    created_by: Mapped[User | None] = relationship(
        "User",
        back_populates="marketplace_items_created",
        lazy="selectin",
    )

    @property
    def academy_name(self) -> str | None:
        return self.academy.name if self.academy else None
