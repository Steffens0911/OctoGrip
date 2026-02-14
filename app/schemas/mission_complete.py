"""Schema para conclusão por missão."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class MissionCompleteRequest(BaseModel):
    """Body do POST /mission_complete."""

    user_id: UUID
    mission_id: UUID
    usage_type: str = "after_training"  # before_training | after_training


class MissionCompleteResponse(BaseModel):
    """Resposta do POST /mission_complete."""

    user_id: UUID
    mission_id: UUID
    completed_at: datetime
