"""Schema para histórico de missões (PB-03)."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class MissionHistoryItem(BaseModel):
    """Uma missão no histórico."""

    lesson_id: UUID
    lesson_title: str
    completed_at: datetime
    usage_type: str


class MissionHistoryResponse(BaseModel):
    """Resposta GET /mission_usages/history."""

    missions: list[MissionHistoryItem]
