"""Schemas para Professor (CRUD seção professor)."""
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


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

    model_config = ConfigDict(extra="forbid")

    name: str = Field(..., min_length=1, max_length=255)
    email: EmailStr = Field(..., description="E-mail do professor (deve ser válido)")
    academy_id: UUID | None = None


class ProfessorUpdate(BaseModel):
    """Atualização parcial de professor."""

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(None, min_length=1, max_length=255)
    email: EmailStr | None = Field(None, description="E-mail do professor (deve ser válido)")
    academy_id: UUID | None = None
