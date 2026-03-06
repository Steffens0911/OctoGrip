from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TrainingVideoAdminRead(BaseModel):
    id: UUID
    title: str
    youtube_url: str
    points_per_day: int
    is_active: bool
    duration_seconds: int | None
    academy_id: UUID | None = None
    academy_name: str | None = None

    class Config:
        from_attributes = True


class TrainingVideoCreate(BaseModel):
  model_config = ConfigDict(extra="forbid")

  title: str = Field(..., min_length=1, max_length=255)
  youtube_url: str = Field(..., max_length=512)
  points_per_day: int = Field(..., ge=1, le=10000)
  is_active: bool = True
  duration_seconds: int | None = Field(None, ge=1, le=4 * 60 * 60)


class TrainingVideoUpdate(BaseModel):
  model_config = ConfigDict(extra="forbid")

  title: str | None = Field(None, min_length=1, max_length=255)
  youtube_url: str | None = Field(None, max_length=512)
  points_per_day: int | None = Field(None, ge=1, le=10000)
  is_active: bool | None = None
  duration_seconds: int | None = Field(None, ge=1, le=4 * 60 * 60)


class TrainingVideoStudentRead(BaseModel):
  id: UUID
  title: str
  youtube_url: str
  points_per_day: int
  duration_seconds: int | None
  academy_id: UUID | None = None
  academy_name: str | None = None
  has_completed_today: bool
  last_completed_at: datetime | None


class TrainingVideoCompletionResponse(BaseModel):
  training_video_id: UUID
  has_completed_today: bool
  already_completed_today: bool
  points_granted: int | None = None
  new_points_balance: int | None = None
  message: str | None = None

