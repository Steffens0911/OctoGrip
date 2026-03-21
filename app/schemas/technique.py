"""Schema para Technique (listagem e CRUD)."""
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TechniqueRead(BaseModel):
    id: UUID
    academy_id: UUID
    name: str
    slug: str
    description: str | None
    video_url: str | None = None
    base_points: int | None = None

    class Config:
        from_attributes = True


class TechniqueCreate(BaseModel):
    """academy_id obrigatório. Slug opcional (gerado automaticamente a partir do nome)."""

    model_config = ConfigDict(extra="forbid")

    academy_id: UUID
    name: str = Field(..., min_length=1, max_length=255)
    slug: str | None = Field(None, max_length=255)
    description: str | None = None
    video_url: str | None = Field(None, max_length=512)
    base_points: int | None = None


class TechniqueUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(None, max_length=255)
    slug: str | None = Field(None, max_length=255)
    description: str | None = None
    video_url: str | None = Field(None, max_length=512)
    base_points: int | None = None
