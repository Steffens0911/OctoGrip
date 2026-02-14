from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class LessonRead(BaseModel):
    """Schema de leitura para Lesson."""

    id: UUID
    title: str
    slug: str
    video_url: str | None
    content: str | None
    order_index: int
    technique_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True


class LessonCreate(BaseModel):
    """Schema para criar Lesson. Slug opcional (gerado automaticamente a partir do título)."""

    technique_id: UUID
    title: str
    slug: str | None = None
    video_url: str | None = None
    content: str | None = None
    order_index: int = 0


class LessonUpdate(BaseModel):
    """Schema para atualização parcial de Lesson."""

    technique_id: UUID | None = None
    title: str | None = None
    slug: str | None = None
    video_url: str | None = None
    content: str | None = None
    order_index: int | None = None
