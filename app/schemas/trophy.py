"""Schemas para troféus (galeria no perfil)."""
from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

AwardKind = Literal["medal", "trophy"]


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
    earned_tier: TrophyTier | None = None
    gold_count: int = 0
    silver_count: int = 0
    bronze_count: int = 0
