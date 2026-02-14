from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Mission(Base, UUIDMixin):
    """
    Missão do dia: vincula uma Técnica a um período (start_date..end_date).
    Conclusão por missão (MissionUsage.mission_id). A-02: academy_id = override por academia.
    """

    __tablename__ = "missions"

    technique_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("techniques.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    end_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    level: Mapped[str] = mapped_column(String(32), nullable=False, default="beginner", index=True)
    theme: Mapped[str | None] = mapped_column(String(128), nullable=True)
    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
        comment="NULL = missão global; preenchido = override da academia (A-02).",
    )

    academy: Mapped["Academy | None"] = relationship(
        "Academy",
        back_populates="missions",
        lazy="selectin",
    )
    technique: Mapped["Technique"] = relationship(
        "Technique",
        back_populates="missions",
        lazy="joined",
    )
    mission_usages: Mapped[list["MissionUsage"]] = relationship(
        "MissionUsage",
        back_populates="mission",
        lazy="selectin",
    )
