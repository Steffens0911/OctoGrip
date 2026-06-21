"""Schemas Pydantic para treinos lançados e templates (favoritos)."""

import re
from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _validate_time(v: str) -> str:
    if not re.match(r"^([01]\d|2[0-3]):[0-5]\d$", v):
        raise ValueError("Horário deve estar no formato HH:MM (ex: 19:00).")
    return v


# ---------------------------------------------------------------------------
# Templates (favoritos)
# ---------------------------------------------------------------------------

class TrainingTemplateCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: str | None = Field(None, max_length=128)
    start_time: str = Field(..., description="HH:MM")
    tolerance_minutes: int = Field(15, ge=5, le=60)
    sort_order: int = Field(0, ge=0)

    @field_validator("start_time")
    @classmethod
    def check_time(cls, v: str) -> str:
        return _validate_time(v)


class TrainingTemplateUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: str | None = Field(None, max_length=128)
    start_time: str | None = None
    tolerance_minutes: int | None = Field(None, ge=5, le=60)
    sort_order: int | None = Field(None, ge=0)

    @field_validator("start_time")
    @classmethod
    def check_time(cls, v: str | None) -> str | None:
        return _validate_time(v) if v is not None else v


class TrainingTemplateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    academy_id: UUID
    label: str | None
    start_time: str
    tolerance_minutes: int
    sort_order: int
    created_at: datetime


# ---------------------------------------------------------------------------
# Sessions (treinos lançados)
# ---------------------------------------------------------------------------

class TrainingSessionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    class_date: date
    start_time: str = Field(..., description="HH:MM")
    tolerance_minutes: int = Field(15, ge=5, le=60)
    label: str | None = Field(None, max_length=128)
    template_id: UUID | None = None

    @field_validator("start_time")
    @classmethod
    def check_time(cls, v: str) -> str:
        return _validate_time(v)


class TrainingSessionUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    start_time: str | None = None
    tolerance_minutes: int | None = Field(None, ge=5, le=60)
    label: str | None = Field(None, max_length=128)

    @field_validator("start_time")
    @classmethod
    def check_time(cls, v: str | None) -> str | None:
        return _validate_time(v) if v is not None else v


class TrainingSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    academy_id: UUID
    created_by_user_id: UUID | None
    template_id: UUID | None
    class_date: date
    start_time: str
    tolerance_minutes: int
    label: str | None
    status: str
    opened_at: datetime | None
    closed_at: datetime | None
    created_at: datetime
    pre_checkin_count: int = 0


# ---------------------------------------------------------------------------
# Pre-checkin
# ---------------------------------------------------------------------------

class ConfirmantRead(BaseModel):
    """Dados mínimos de quem confirmou presença (para prova social)."""

    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    name: str
    avatar_url: str | None = None


class PreCheckinRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    training_session_id: UUID
    user_id: UUID
    academy_id: UUID
    status: str
    confirmed_at: datetime | None
    cancelled_at: datetime | None
    created_at: datetime


class PreCheckinStatusRead(BaseModel):
    """Estado do pré-checkin do usuário atual para uma sessão."""

    model_config = ConfigDict(from_attributes=True)

    pre_checkin_id: UUID | None = None
    status: str | None = None
    confirmed_at: datetime | None = None
    cancelled_at: datetime | None = None
    confirmants: list[ConfirmantRead] = []
    total_confirmed: int = 0


# ---------------------------------------------------------------------------
# Resumo pós-treino (furo inteligente)
# ---------------------------------------------------------------------------

class PersonSummaryRead(BaseModel):
    """Dados mínimos de uma pessoa para o resumo pós-treino."""

    user_id: UUID
    name: str | None = None
    avatar_url: str | None = None


class TrainingSessionSummaryRead(BaseModel):
    """Cruzamento pré-confirmados × presenças reais após o treino."""

    training_session_id: UUID
    label: str | None
    class_date: date
    start_time: str
    total_pre_confirmed: int
    total_attended: int
    confirmed_and_attended: list[PersonSummaryRead]
    furos: list[PersonSummaryRead]
    surpresas: list[PersonSummaryRead]
