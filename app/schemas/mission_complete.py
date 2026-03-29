"""Schema para conclusão por missão."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class MissionCompleteRequest(BaseModel):
    """Body do POST /mission_complete. user_id vem do token (autenticação)."""

    model_config = ConfigDict(extra="forbid")

    mission_id: UUID
    usage_type: str = "after_training"  # before_training | after_training


class MissionCompleteResponse(BaseModel):
    """Resposta do POST /mission_complete."""

    user_id: UUID
    mission_id: UUID
    completed_at: datetime
    points_awarded: int
