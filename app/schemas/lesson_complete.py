from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class LessonCompleteRequest(BaseModel):
    """Corpo da requisição para registrar conclusão de lição."""

    user_id: UUID
    lesson_id: UUID


class LessonCompleteResponse(BaseModel):
    """Resposta do endpoint de conclusão de lição."""

    lesson_id: UUID
    user_id: UUID
    completed_at: datetime

    class Config:
        from_attributes = True


class LessonCompleteStatusResponse(BaseModel):
    """Resposta GET /lesson_complete/status — indica se a lição já foi concluída pelo usuário."""

    completed: bool
