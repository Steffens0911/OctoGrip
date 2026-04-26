"""Schemas para parceiros globais (admin global + banner da Central)."""
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class GlobalPartnerRead(BaseModel):
    id: UUID
    name: str
    description: str | None
    logo_url: str | None
    offer_text: str | None
    external_url: str | None
    button_label: str | None
    featured_order: int | None
    is_active: bool

    class Config:
        from_attributes = True


class GlobalPartnerCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(None, max_length=2000)
    logo_url: str | None = Field(None, max_length=512)
    offer_text: str | None = Field(None, max_length=2000)
    external_url: str | None = Field(None, max_length=512)
    button_label: str | None = Field(None, max_length=18)
    featured_order: int | None = None
    is_active: bool = True


class GlobalPartnerUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = Field(None, max_length=2000)
    logo_url: str | None = Field(None, max_length=512)
    offer_text: str | None = Field(None, max_length=2000)
    external_url: str | None = Field(None, max_length=512)
    button_label: str | None = Field(None, max_length=18)
    featured_order: int | None = None
    is_active: bool | None = None
