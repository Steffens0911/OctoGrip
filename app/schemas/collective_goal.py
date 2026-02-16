"""Schemas para metas coletivas."""
from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, Field


class CollectiveGoalRead(BaseModel):
    id: UUID
    academy_id: UUID | None
    technique_id: UUID
    target_count: int
    start_date: date
    end_date: date
    created_at: datetime
    technique_name: str | None = None

    class Config:
        from_attributes = True


class CollectiveGoalCreate(BaseModel):
    academy_id: UUID | None = None
    technique_id: UUID
    target_count: int = Field(..., gt=0)
    start_date: date
    end_date: date


class CollectiveGoalCurrentResponse(BaseModel):
    """Meta atual da semana com progresso."""
    goal: CollectiveGoalRead
    current_count: int
    target_count: int
