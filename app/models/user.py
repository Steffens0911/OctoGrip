from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class User(Base, UUIDMixin):
    """Usuário do sistema (A-01: vinculado a academia quando informado)."""

    __tablename__ = "users"

    # Único em toda a tabela users (todas as academias); não há unicidade “por academia”.
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True, comment="Hash pbkdf2_sha256 da senha para login.")
    name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    points_adjustment: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    reward_level: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        comment="Nível do usuário baseado no total de pontos (level-up). Nível 1 começa em 0 e avança ao atingir 50 pontos.",
    )
    reward_level_points: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        comment="Pontos acumulados dentro do nível atual (carry over quando o usuário sobe).",
    )
    graduation: Mapped[str | None] = mapped_column(
        String(32),
        nullable=True,
        index=True,
        comment="Faixa: white, blue, purple, brown, black.",
    )
    role: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="aluno",
        index=True,
        comment="Role: aluno, professor, gerente_academia, administrador, supervisor",
    )
    academy_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academies.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    gallery_visible: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        comment="Se true, outros usuários podem ver a galeria de troféus (apenas conquistados).",
    )
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
        comment="Data/hora do último login bem-sucedido.",
    )
    account_frozen: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
        comment="Se true (e role=aluno), a API bloqueia ações mutáveis; login e leitura seguem permitidos.",
    )
    account_freeze_reason: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Motivo opcional exibido ao aluno (ex.: mensalidade). Gestor/admin define.",
    )
    avatar_url: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="URL pública da foto do utilizador usada por módulos de reconhecimento facial.",
    )

    academy: Mapped["Academy | None"] = relationship(
        "Academy",
        back_populates="users",
        lazy="selectin",
    )
    lesson_progresses: Mapped[list["LessonProgress"]] = relationship(
        "LessonProgress",
        back_populates="user",
        lazy="selectin",
    )
    training_feedbacks: Mapped[list["TrainingFeedback"]] = relationship(
        "TrainingFeedback",
        back_populates="user",
        lazy="selectin",
    )
    mission_usages: Mapped[list["MissionUsage"]] = relationship(
        "MissionUsage",
        back_populates="user",
        lazy="selectin",
    )
    technique_executions_as_executor: Mapped[list["TechniqueExecution"]] = relationship(
        "TechniqueExecution",
        foreign_keys="TechniqueExecution.user_id",
        back_populates="user",
        lazy="selectin",
    )
    technique_executions_as_opponent: Mapped[list["TechniqueExecution"]] = relationship(
        "TechniqueExecution",
        foreign_keys="TechniqueExecution.opponent_id",
        back_populates="opponent",
        lazy="selectin",
    )
    training_videos: Mapped[list["TrainingVideo"]] = relationship(
        "TrainingVideo",
        back_populates="created_by",
        lazy="selectin",
    )
    marketplace_items_created: Mapped[list["AcademyMarketplaceItem"]] = relationship(
        "AcademyMarketplaceItem",
        back_populates="created_by",
        lazy="selectin",
    )
    training_video_daily_views: Mapped[list["TrainingVideoDailyView"]] = relationship(
        "TrainingVideoDailyView",
        back_populates="user",
        lazy="selectin",
    )
    device_tokens: Mapped[list["UserDeviceToken"]] = relationship(
        "UserDeviceToken",
        back_populates="user",
        lazy="selectin",
        cascade="all, delete-orphan",
    )
    weekly_kit_choices: Mapped[list["UserWeeklyKitChoice"]] = relationship(
        "UserWeeklyKitChoice",
        back_populates="user",
        lazy="selectin",
    )
