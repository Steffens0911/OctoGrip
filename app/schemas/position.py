"""Schema para Position (listagem e CRUD)."""
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PositionRead(BaseModel):
    id: UUID
    academy_id: UUID
    name: str
    slug: str
    description: str | None

    class Config:
        from_attributes = True


class PositionCreate(BaseModel):
    """Criação de posição. academy_id obrigatório. Slug opcional (gerado automaticamente)."""

    model_config = ConfigDict(extra="forbid")

    academy_id: UUID
    name: str = Field(..., min_length=1, max_length=255)
    slug: str | None = Field(None, max_length=255)
    description: str | None = None


class PositionUpdate(BaseModel):
    """Atualização parcial de posição."""

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(None, max_length=255)
    slug: str | None = Field(None, max_length=255)
    description: str | None = None
