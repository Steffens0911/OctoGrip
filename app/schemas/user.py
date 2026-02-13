"""Schemas para User (CRUD desenvolvedores)."""
from uuid import UUID

from pydantic import BaseModel, Field


class UserRead(BaseModel):
    id: UUID
    email: str
    name: str | None
    academy_id: UUID | None

    class Config:
        from_attributes = True


class UserCreate(BaseModel):
    email: str = Field(..., min_length=1, max_length=255)
    name: str | None = Field(None, max_length=255)
    academy_id: UUID | None = None


class UserUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    academy_id: UUID | None = None
