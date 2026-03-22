"""Schemas para metas coletivas."""
from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


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
    model_config = ConfigDict(extra="forbid")

    academy_id: UUID | None = None
    technique_id: UUID
    target_count: int = Field(..., gt=0)
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def end_after_start(self):
        if self.end_date < self.start_date:
            raise ValueError("end_date deve ser igual ou posterior a start_date")
        return self


class CollectiveGoalCurrentResponse(BaseModel):
    """Meta atual da semana com progresso."""
    goal: CollectiveGoalRead
    current_count: int
    target_count: int
