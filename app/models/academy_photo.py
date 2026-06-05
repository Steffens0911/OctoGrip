"""Models para OctoPhotos — feed de fotos por academia (feature premium)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin
from app.models.soft_delete import SoftDeleteMixin


class AcademyPhoto(Base, UUIDMixin, SoftDeleteMixin):
    """Post de foto no feed da academia."""

    __tablename__ = "academy_photos"
    __table_args__ = (
        # Índice parcial cobre o feed paginado (academy_id + created_at DESC, só posts ativos)
        Index("ix_academy_photos_feed", "academy_id", "created_at", postgresql_where="deleted_at IS NULL"),
        Index("ix_academy_photos_status", "status", postgresql_where="deleted_at IS NULL"),
    )

    academy_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    raw_file_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="processing")
    likes_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    comments_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_system_post: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    system_post_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    system_post_ref_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True), nullable=True)

    author: Mapped[User] = relationship("User", foreign_keys=[author_id], lazy="selectin")
    likes: Mapped[list[AcademyPhotoLike]] = relationship(
        "AcademyPhotoLike", back_populates="photo", lazy="raise", passive_deletes=True
    )


class AcademyPhotoComment(Base, UUIDMixin):
    """Comentário em um post de foto."""

    __tablename__ = "academy_photo_comments"
    __table_args__ = (
        Index("ix_photo_comments_photo", "photo_id", "created_at", postgresql_where="deleted_at IS NULL"),
    )

    photo_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("academy_photos.id", ondelete="CASCADE"),
        nullable=False,
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    author: Mapped[User] = relationship("User", foreign_keys=[author_id], lazy="selectin")


class AcademyPhotoLike(Base):
    """Curtida de um usuário em um post de foto (PK composta, sem UUID próprio)."""

    __tablename__ = "academy_photo_likes"

    photo_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("academy_photos.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    photo: Mapped[AcademyPhoto] = relationship("AcademyPhoto", back_populates="likes")


class AcademyPhotoRestriction(Base, UUIDMixin):
    """Restrição de postagem de um aluno na academia (gerente/admin podem restringir temporária ou permanentemente)."""

    __tablename__ = "academy_photo_restrictions"

    academy_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("academies.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    restricted_by: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id"),
        nullable=False,
    )
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    restricted_user: Mapped[User] = relationship("User", foreign_keys=[user_id], lazy="selectin")
    restricted_by_user: Mapped[User] = relationship("User", foreign_keys=[restricted_by], lazy="selectin")
