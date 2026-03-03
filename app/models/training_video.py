from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class TrainingVideo(Base, UUIDMixin):
    """
    Vídeo de treinamento voluntário (campo de treinamento).
    Pontua uma vez por dia por usuário.
    """

    __tablename__ = "training_videos"

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    youtube_url: Mapped[str] = mapped_column(String(512), nullable=False)
    points_per_day: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    order_index: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    created_by: Mapped["User | None"] = relationship("User", back_populates="training_videos", lazy="selectin")
    daily_views: Mapped[list["TrainingVideoDailyView"]] = relationship(
        "TrainingVideoDailyView",
        back_populates="training_video",
        lazy="selectin",
    )


class TrainingVideoDailyView(Base, UUIDMixin):
    """
    Visualização diária de um vídeo de treinamento por usuário.
    Garante 1 linha por (user_id, training_video_id, view_date).
    """

    __tablename__ = "training_video_daily_views"
    __table_args__ = (
        UniqueConstraint("user_id", "training_video_id", "view_date", name="uq_training_video_daily_view_unique"),
        Index("ix_training_video_daily_views_user_date", "user_id", "view_date"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    training_video_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("training_videos.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    view_date: Mapped[date] = mapped_column(Date, nullable=False)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    points_awarded: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    user: Mapped["User"] = relationship("User", back_populates="training_video_daily_views")
    training_video: Mapped["TrainingVideo"] = relationship(
        "TrainingVideo",
        back_populates="daily_views",
    )

