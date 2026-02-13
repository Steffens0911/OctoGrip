"""Schemas para Professor (CRUD seção professor)."""
from uuid import UUID

from pydantic import BaseModel, Field


class ProfessorRead(BaseModel):
    """Leitura de um professor."""

    id: UUID
    name: str
    email: str
    academy_id: UUID | None

    class Config:
        from_attributes = True


class ProfessorCreate(BaseModel):
    """Criação de professor."""

    name: str = Field(..., min_length=1, max_length=255)
    email: str = Field(..., min_length=1, max_length=255)
    academy_id: UUID | None = None


class ProfessorUpdate(BaseModel):
    """Atualização parcial de professor."""

    name: str | None = Field(None, min_length=1, max_length=255)
    email: str | None = Field(None, min_length=1, max_length=255)
    academy_id: UUID | None = None
