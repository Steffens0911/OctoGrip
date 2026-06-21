from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel


class FaceArriveResponse(BaseModel):
    """Resposta do quiosque facial após processar um frame de chegada."""

    matched: bool
    confidence: float
    student_id: UUID | None = None
    student_name: str | None = None
    was_punctual: bool | None = None
    punctuality_streak: int | None = None
    xp_awarded: int = 0
    greeting: str
    duplicate: bool = False
