"""Schema para Technique (listagem e CRUD)."""
from uuid import UUID

from pydantic import BaseModel, Field


class TechniqueRead(BaseModel):
    id: UUID
    name: str
    slug: str
    description: str | None
    from_position_id: UUID
    to_position_id: UUID

    class Config:
        from_attributes = True


class TechniqueCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    slug: str = Field(..., max_length=255)
    description: str | None = None
    from_position_id: UUID
    to_position_id: UUID


class TechniqueUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    slug: str | None = Field(None, max_length=255)
    description: str | None = None
    from_position_id: UUID | None = None
    to_position_id: UUID | None = None
