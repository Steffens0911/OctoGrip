from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class TrainingFeedbackRequest(BaseModel):
    """Corpo da requisição para registrar feedback de treino. user_id vem do token."""

    model_config = ConfigDict(extra="forbid")

    position_id: UUID
    observation: str | None = None


class TrainingFeedbackResponse(BaseModel):
    """Resposta do endpoint de feedback de treino."""

    id: UUID
    user_id: UUID
    position_id: UUID
    observation: str | None
    created_at: datetime

    class Config:
        from_attributes = True
