"""Academia (B2B): usuário vinculado (A-01), missão por academia (A-02)."""
from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String, Text, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.base import UUIDMixin


class Academy(Base, UUIDMixin):
    """Academia: agrupa usuários e pode ter missões próprias (override global)."""

    __tablename__ = "academies"

    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    slug: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    logo_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="URL do brasão/logo exibido no topo do app para alunos da academia.",
    )
    schedule_image_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="URL de uma imagem com o quadro de horários da academia (home do aluno).",
    )
    weekly_theme: Mapped[str | None] = mapped_column(
        String(128),
        nullable=True,
        comment="A-03: tema semanal (legado); preferir weekly_technique_id.",
    )
    weekly_technique_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Técnica slot 1 (seg-ter) ou missão única da semana se 2 e 3 forem null.",
    )
    weekly_technique_2_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Técnica slot 2 (qua-qui).",
    )
    weekly_technique_3_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("techniques.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Técnica slot 3 (sex-dom).",
    )
    visible_lesson_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("lessons.id", ondelete="SET NULL", use_alter=True),
        nullable=True,
        index=True,
        comment="Lição em destaque visível para os alunos da academia.",
    )
    weekly_multiplier_1: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    weekly_multiplier_2: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    weekly_multiplier_3: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    show_trophies: Mapped[bool] = mapped_column(
        default=True,
        server_default=text("true"),
        nullable=False,
        comment="Controle da home do aluno: exibe ou não o acordeon de troféus.",
    )
    show_partners: Mapped[bool] = mapped_column(
        default=True,
        server_default=text("true"),
        nullable=False,
        comment="Controle da home do aluno: exibe ou não o acordeon de parceiros.",
    )
    show_schedule: Mapped[bool] = mapped_column(
        default=True,
        server_default=text("true"),
        nullable=False,
        comment="Controle da home do aluno: exibe ou não o quadro de horários (mesmo havendo imagem).",
    )
    show_global_supporters: Mapped[bool] = mapped_column(
        default=True,
        server_default=text("true"),
        nullable=False,
        comment="Controle da home do aluno: exibe ou não o quadro de apoiadores globais do app.",
    )
    login_notice_title: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Título opcional do aviso ao abrir o app (modal na home).",
    )
    login_notice_body: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Corpo do aviso ao abrir o app; exibido se ativo e não vazio.",
    )
    login_notice_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True,
        comment="URL opcional (ex.: regulamento) no modal de aviso.",
    )
    login_notice_active: Mapped[bool] = mapped_column(
        default=False,
        server_default=text("false"),
        nullable=False,
        comment="Se verdadeiro e corpo preenchido, o app pode mostrar o aviso ao entrar na home.",
    )

    weekly_technique: Mapped["Technique | None"] = relationship(
        "Technique",
        foreign_keys=[weekly_technique_id],
        lazy="selectin",
    )
    weekly_technique_2: Mapped["Technique | None"] = relationship(
        "Technique",
        foreign_keys=[weekly_technique_2_id],
        lazy="selectin",
    )
    weekly_technique_3: Mapped["Technique | None"] = relationship(
        "Technique",
        foreign_keys=[weekly_technique_3_id],
        lazy="selectin",
    )
    visible_lesson: Mapped["Lesson | None"] = relationship(
        "Lesson",
        foreign_keys=[visible_lesson_id],
        lazy="selectin",
    )
    # passive_deletes: ao apagar a academia, não emitir UPDATE para anular academy_id nos filhos.
    # Técnicas/troféus têm academy_id NOT NULL; a FK na BD usa ON DELETE CASCADE.
    users: Mapped[list["User"]] = relationship(
        "User",
        back_populates="academy",
        lazy="selectin",
        passive_deletes=True,
    )
    professors: Mapped[list["Professor"]] = relationship(
        "Professor",
        back_populates="academy",
        lazy="selectin",
        passive_deletes=True,
    )
    missions: Mapped[list["Mission"]] = relationship(
        "Mission",
        back_populates="academy",
        lazy="selectin",
        passive_deletes=True,
    )
    collective_goals: Mapped[list["CollectiveGoal"]] = relationship(
        "CollectiveGoal",
        back_populates="academy",
        lazy="selectin",
        passive_deletes=True,
    )
    techniques: Mapped[list["Technique"]] = relationship(
        "Technique",
        back_populates="academy",
        foreign_keys="Technique.academy_id",
        lazy="selectin",
        passive_deletes=True,
    )
    trophies: Mapped[list["Trophy"]] = relationship(
        "Trophy",
        back_populates="academy",
        lazy="selectin",
        passive_deletes=True,
    )
    partners: Mapped[list["Partner"]] = relationship(
        "Partner",
        back_populates="academy",
        lazy="selectin",
        passive_deletes=True,
    )
    training_videos: Mapped[list["TrainingVideo"]] = relationship(
        "TrainingVideo",
        back_populates="academy",
        lazy="selectin",
        passive_deletes=True,
    )