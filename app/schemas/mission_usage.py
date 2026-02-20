"""Schemas para sync de MissionUsage (PB-01)."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class MissionUsageItem(BaseModel):
    """Um item de uso para sync (payload do app)."""

    model_config = ConfigDict(extra="forbid")

    lesson_id: UUID
    opened_at: datetime
    completed_at: datetime
    usage_type: str = Field(..., pattern="^(before_training|after_training)$")


class MissionUsageSyncRequest(BaseModel):
    """Body do POST /mission_usages/sync. user_id vem do token."""

    model_config = ConfigDict(extra="forbid")

    usages: list[MissionUsageItem]


class MissionUsageSyncResponse(BaseModel):
    """Resposta do sync: quantos foram inseridos."""

    synced: int
    message: str = "Sync concluído."
