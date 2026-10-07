"""Schemas para listagens de pessoas da academia (chamada, relatórios)."""

from uuid import UUID

from pydantic import BaseModel


class AcademyStudentListItem(BaseModel):
    id: UUID
    name: str | None = None
    belt: str | None = None
    avatar_url: str | None = None
    role: str | None = None
