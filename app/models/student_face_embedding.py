from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class StudentFaceEmbedding(Base, UUIDMixin):
    """Embedding facial persistido por aluno para reconhecimento de chamada."""

    __tablename__ = "student_face_embedding"

    student_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    academy_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    embedding: Mapped[list[float]] = mapped_column(JSONB, nullable=False)

    student: Mapped["User"] = relationship("User", lazy="selectin")
    academy: Mapped["Academy"] = relationship("Academy", lazy="selectin")
