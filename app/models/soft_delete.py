"""Mixin reutilizável para soft delete (deleted_at)."""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime
from sqlalchemy.orm import Mapped, mapped_column


class SoftDeleteMixin:
    """Marca registros como removidos sem apagar a linha (queries padrão filtram deleted_at IS NULL)."""

    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )
