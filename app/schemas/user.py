"""Schemas para User (CRUD desenvolvedores)."""
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class UserRead(BaseModel):
    id: UUID
    email: str
    name: str | None
    graduation: str | None = None
    academy_id: UUID | None = None

    class Config:
        from_attributes = True


VALID_GRADUATIONS = frozenset({"white", "blue", "purple", "brown", "black"})


def _validate_graduation(v: str | None) -> str:
    if not v or not v.strip():
        raise ValueError("graduation é obrigatório")
    g = v.strip().lower()
    if g not in VALID_GRADUATIONS:
        raise ValueError(
            f"graduation deve ser um de: {', '.join(sorted(VALID_GRADUATIONS))}"
        )
    return g


class UserCreate(BaseModel):
    email: str = Field(..., min_length=1, max_length=255)
    name: str | None = Field(None, max_length=255)
    graduation: str = Field(..., min_length=1, max_length=32)
    academy_id: UUID | None = None

    @field_validator("graduation")
    @classmethod
    def graduation_valid(cls, v: str) -> str:
        return _validate_graduation(v)


class UserUpdate(BaseModel):
    name: str | None = Field(None, max_length=255)
    graduation: str | None = Field(None, max_length=32)
    academy_id: UUID | None = None

    @field_validator("graduation")
    @classmethod
    def graduation_valid(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return _validate_graduation(v)
