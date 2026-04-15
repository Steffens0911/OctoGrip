"""Kit semanal de técnicas (rótulo de turma), 1–5 itens por kit."""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class WeeklyTechniqueKit(Base, UUIDMixin):
    __tablename__ = "weekly_technique_kits"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label: Mapped[str] = mapped_column(String(255), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    academy: Mapped["Academy"] = relationship("Academy", back_populates="weekly_technique_kits")
    items: Mapped[list["WeeklyKitItem"]] = relationship(
        "WeeklyKitItem",
        back_populates="kit",
        order_by="WeeklyKitItem.order_index",
        cascade="all, delete-orphan",
    )
    missions: Mapped[list["Mission"]] = relationship(
        "Mission",
        back_populates="weekly_kit",
        lazy="dynamic",
    )


class WeeklyKitItem(Base, UUIDMixin):
    __tablename__ = "weekly_kit_items"

    kit_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("weekly_technique_kits.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    technique_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("techniques.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    multiplier: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    kit: Mapped["WeeklyTechniqueKit"] = relationship("WeeklyTechniqueKit", back_populates="items")
    technique: Mapped["Technique"] = relationship("Technique", lazy="joined")


class UserWeeklyKitChoice(Base, UUIDMixin):
    __tablename__ = "user_weekly_kit_choices"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    iso_week_year: Mapped[int] = mapped_column(Integer, nullable=False)
    iso_week_number: Mapped[int] = mapped_column(Integer, nullable=False)
    kit_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("weekly_technique_kits.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    chosen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="weekly_kit_choices", lazy="selectin")
    academy: Mapped["Academy"] = relationship("Academy", back_populates="user_weekly_kit_choices")
    kit: Mapped["WeeklyTechniqueKit"] = relationship("WeeklyTechniqueKit", lazy="joined")
