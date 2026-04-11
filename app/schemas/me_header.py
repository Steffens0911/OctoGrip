"""Schemas do header da home do aluno."""
from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field


class MeHeaderAcademyRead(BaseModel):
    """Resumo de configurações da academia usadas no header/home."""

    id: UUID
    name: str
    logo_url: str | None = None
    schedule_image_url: str | None = None
    show_trophies: bool = True
    show_partners: bool = True
    show_schedule: bool = True
    show_global_supporters: bool = True


class MeHeaderStatsRead(BaseModel):
    """Payload agregado para render rápido do header da home."""

    user_id: UUID
    reward_level: int = Field(1, ge=1)
    reward_level_points: int = Field(0, ge=0)
    next_level_threshold: int = Field(50, ge=1)
    academy: MeHeaderAcademyRead | None = None
