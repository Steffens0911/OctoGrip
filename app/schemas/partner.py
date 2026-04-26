"""Schema para Partner (listagem e CRUD)."""
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PartnerRead(BaseModel):
    id: UUID
    academy_id: UUID
    name: str
    description: str | None
    url: str | None
    logo_url: str | None
    highlight_on_login: bool
    is_active: bool
    is_featured: bool
    featured_order: int | None
    offer_text: str | None
    external_url: str | None

    class Config:
        from_attributes = True


class PartnerCreate(BaseModel):
    """Criação de parceiro. academy_id obrigatório."""

    model_config = ConfigDict(extra="forbid")

    academy_id: UUID
    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(None, max_length=2000)
    url: str | None = Field(None, max_length=512)
    logo_url: str | None = Field(None, max_length=512)
    highlight_on_login: bool = False
    is_active: bool = True
    is_featured: bool = False
    featured_order: int | None = None
    offer_text: str | None = Field(None, max_length=2000)
    external_url: str | None = Field(None, max_length=512)


class PartnerUpdate(BaseModel):
    """Atualização parcial de parceiro."""

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = Field(None, max_length=2000)
    url: str | None = Field(None, max_length=512)
    logo_url: str | None = Field(None, max_length=512)
    highlight_on_login: bool | None = None
    is_active: bool | None = None
    is_featured: bool | None = None
    featured_order: int | None = None
    offer_text: str | None = Field(None, max_length=2000)
    external_url: str | None = Field(None, max_length=512)
