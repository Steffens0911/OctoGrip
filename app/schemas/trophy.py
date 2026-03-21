"""Schemas para troféus (galeria no perfil)."""
from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

AwardKind = Literal["medal", "trophy"]
VALID_GRADUATIONS = frozenset({"white", "blue", "purple", "brown", "black"})


class TrophyCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    academy_id: UUID
    technique_id: UUID
    name: str = Field(..., min_length=1, max_length=255)
    start_date: date
    end_date: date
    target_count: int = Field(..., gt=0)
    award_kind: AwardKind = Field(default="trophy", description="medal=ordinária, trophy=especial")
    min_duration_days: int | None = Field(default=None, description="Obrigatório para trophy (ex: 30)")
    min_points_to_unlock: int = Field(default=0, ge=0, description="Pontos mínimos do aluno para desbloquear; 0 = todos")
    min_graduation_to_unlock: str | None = Field(default=None, description="Faixa mínima (white, blue, purple, brown, black); null = todos")

    @field_validator("min_graduation_to_unlock")
    @classmethod
    def validate_min_graduation(cls, v: str | None) -> str | None:
        if not v or not v.strip():
            return None
        g = v.strip().lower()
        if g not in VALID_GRADUATIONS:
            raise ValueError(f"min_graduation_to_unlock deve ser um de: {', '.join(sorted(VALID_GRADUATIONS))}")
        return g


class TrophyUpdate(BaseModel):
    """Atualização parcial de troféu (admin)."""

    model_config = ConfigDict(extra="forbid")

    technique_id: UUID | None = None
    name: str | None = Field(None, min_length=1, max_length=255)
    start_date: date | None = None
    end_date: date | None = None
    target_count: int | None = Field(None, gt=0)
    award_kind: AwardKind | None = None
    min_duration_days: int | None = Field(default=None, description="Para trophy")
    min_points_to_unlock: int | None = Field(None, ge=0)
    min_graduation_to_unlock: str | None = None

    @field_validator("min_graduation_to_unlock")
    @classmethod
    def validate_min_graduation_u(cls, v: str | None) -> str | None:
        if not v or not v.strip():
            return None
        g = v.strip().lower()
        if g not in VALID_GRADUATIONS:
            raise ValueError(f"min_graduation_to_unlock deve ser um de: {', '.join(sorted(VALID_GRADUATIONS))}")
        return g


class TrophyRead(BaseModel):
    id: UUID
    academy_id: UUID
    technique_id: UUID
    technique_name: str | None = None
    name: str
    start_date: date
    end_date: date
    target_count: int
    award_kind: str = "trophy"
    min_duration_days: int | None = None
    min_points_to_unlock: int = 0
    min_graduation_to_unlock: str | None = None
    created_at: datetime | None = None

    class Config:
        from_attributes = True


TrophyTier = Literal["bronze", "silver", "gold"]


class UserTrophyEarned(BaseModel):
    """Item da galeria: troféu ou medalha com tier conquistado (ou nenhum)."""
    trophy_id: UUID
    technique_id: UUID
    academy_id: UUID | None = None
    name: str
    technique_name: str | None = None
    start_date: date
    end_date: date
    target_count: int
    award_kind: str = "trophy"
    min_duration_days: int | None = None
    min_points_to_unlock: int = 0
    min_graduation_to_unlock: str | None = None
    unlocked: bool = True
    earned_tier: TrophyTier | None = None
    gold_count: int = 0
    silver_count: int = 0
    bronze_count: int = 0
