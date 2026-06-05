"""Schemas para troféus manuais: templates, campeonatos e concessões."""

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

TrophyType = Literal["championship", "custom"]
MedalType = Literal["gold", "silver", "bronze", "participation"]


# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------


class TrophyTemplateCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    academy_id: UUID
    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=1000)
    icon: str | None = Field(default=None, max_length=128)
    color: str | None = Field(default=None, max_length=32)
    trophy_type: TrophyType = "custom"

    @field_validator("color")
    @classmethod
    def validate_color(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if v and not v.startswith("#"):
            raise ValueError("color deve ser um hex CSS (ex: #FFD700)")
        return v or None


class TrophyTemplateUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=128)
    color: str | None = Field(default=None, max_length=32)


class TrophyTemplateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    academy_id: UUID
    name: str
    description: str | None = None
    icon: str | None = None
    color: str | None = None
    trophy_type: str
    created_by: UUID | None = None
    created_at: datetime


# ---------------------------------------------------------------------------
# Campeonatos
# ---------------------------------------------------------------------------


class ChampionshipEventCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    academy_id: UUID
    name: str = Field(..., min_length=1, max_length=255)
    location: str | None = Field(default=None, max_length=255)
    event_date: date


class ChampionshipEventUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=255)
    location: str | None = None
    event_date: date | None = None


class ChampionshipEventRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    academy_id: UUID
    name: str
    location: str | None = None
    event_date: date
    created_by: UUID | None = None
    created_at: datetime


# ---------------------------------------------------------------------------
# Concessões
# ---------------------------------------------------------------------------


class TrophyAwardCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    template_id: UUID
    user_id: UUID
    championship_event_id: UUID | None = None
    medal_type: MedalType | None = None
    note: str | None = Field(default=None, max_length=500)


class TrophyAwardRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    template_id: UUID
    template_name: str
    template_icon: str | None = None
    template_color: str | None = None
    trophy_type: str
    user_id: UUID
    awarded_by: UUID | None = None
    awarded_at: datetime
    championship_event_id: UUID | None = None
    championship_event_name: str | None = None
    championship_event_date: date | None = None
    medal_type: str | None = None
    note: str | None = None


class UserTrophyAwardsResponse(BaseModel):
    """Todas as concessões de um aluno agrupadas por tipo."""

    user_id: UUID
    championship_awards: list[TrophyAwardRead]
    custom_awards: list[TrophyAwardRead]
