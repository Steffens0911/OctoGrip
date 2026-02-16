"""Schemas para Academia (A-03, A-04)."""
from uuid import UUID

from pydantic import BaseModel, Field


class AcademyCreate(BaseModel):
    """Criação de academia."""

    name: str = Field(..., min_length=1, max_length=255)
    slug: str | None = Field(None, max_length=255)


class AcademyRead(BaseModel):
    """Leitura de uma academia."""

    id: UUID
    name: str
    slug: str | None
    weekly_theme: str | None = None
    weekly_technique_id: UUID | None = None
    weekly_technique_name: str | None = None
    weekly_technique_2_id: UUID | None = None
    weekly_technique_2_name: str | None = None
    weekly_technique_3_id: UUID | None = None
    weekly_technique_3_name: str | None = None
    visible_lesson_id: UUID | None = None
    visible_lesson_name: str | None = None
    weekly_multiplier_1: int = 1
    weekly_multiplier_2: int = 1
    weekly_multiplier_3: int = 1

    class Config:
        from_attributes = True


class AcademyUpdateWeeklyTheme(BaseModel):
    """Atualização do tema semanal (A-03: professor define)."""

    weekly_theme: str | None = Field(None, max_length=128)


class AcademyUpdate(BaseModel):
    """Atualização parcial da academia (CRUD). Até 3 técnicas = 3 missões semanais (seg-ter, qua-qui, sex-dom)."""

    name: str | None = Field(None, min_length=1, max_length=255)
    slug: str | None = Field(None, max_length=255)
    weekly_theme: str | None = Field(None, max_length=128)
    weekly_technique_id: UUID | None = None
    weekly_technique_2_id: UUID | None = None
    weekly_technique_3_id: UUID | None = None
    visible_lesson_id: UUID | None = None
    weekly_multiplier_1: int | None = None
    weekly_multiplier_2: int | None = None
    weekly_multiplier_3: int | None = None


class RankingEntry(BaseModel):
    """Uma posição no ranking interno (A-04)."""

    rank: int
    user_id: UUID
    name: str | None
    completions_count: int


class RankingResponse(BaseModel):
    """Resposta GET /academies/{id}/ranking (A-04)."""

    academy_id: UUID
    period_days: int
    entries: list[RankingEntry]


class DifficultyEntry(BaseModel):
    """T-02: Posição com quantidade de feedbacks de dificuldade."""

    position_id: UUID
    position_name: str
    count: int


class DifficultiesResponse(BaseModel):
    """Resposta GET /academies/{id}/difficulties (T-02)."""

    academy_id: UUID
    entries: list[DifficultyEntry]


class WeeklyReportResponse(BaseModel):
    """T-03: Relatório semanal da academia (export simples)."""

    academy_id: UUID
    week_start: str
    week_end: str
    completions_count: int
    active_users_count: int
    entries: list[RankingEntry]
