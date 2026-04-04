"""Dias UTC com login bem-sucedido (sequência de login)."""
from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import Date, ForeignKey, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class UserLoginDay(Base):
    __tablename__ = "user_login_days"
    __table_args__ = (Index("idx_user_login_days_user_day", "user_id", "login_day"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    login_day: Mapped[date] = mapped_column(Date, primary_key=True, nullable=False)
