from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.academy_marketplace_item import AcademyMarketplaceItem
from app.utils.marketplace_whatsapp import (
    build_whatsapp_url,
    split_br_phone_for_editor,
)


def marketplace_item_admin_read_from_orm(
    item: AcademyMarketplaceItem,
) -> MarketplaceItemAdminRead:
    ddd, num = split_br_phone_for_editor(item.whatsapp_phone)
    url = None
    if item.whatsapp_phone:
        url = build_whatsapp_url(phone=item.whatsapp_phone, title=item.title)
    return MarketplaceItemAdminRead(
        id=item.id,
        academy_id=item.academy_id,
        academy_name=item.academy_name,
        title=item.title,
        description=item.description,
        price_cents=item.price_cents,
        currency=item.currency,
        image_url=item.image_url,
        whatsapp_ddd=ddd,
        whatsapp_number=num,
        whatsapp_url=url,
        sort_order=item.sort_order,
        is_active=item.is_active,
        whatsapp_clicks=item.whatsapp_clicks,
    )


def marketplace_item_student_read_from_orm(
    item: AcademyMarketplaceItem,
) -> MarketplaceItemStudentRead:
    url = None
    if item.whatsapp_phone:
        url = build_whatsapp_url(phone=item.whatsapp_phone, title=item.title)
    return MarketplaceItemStudentRead(
        id=item.id,
        title=item.title,
        description=item.description,
        price_cents=item.price_cents,
        currency=item.currency,
        image_url=item.image_url,
        whatsapp_url=url,
    )


class MarketplaceItemAdminRead(BaseModel):
    id: UUID
    academy_id: UUID
    academy_name: str | None = None
    title: str
    description: str | None
    price_cents: int
    currency: str
    image_url: str | None
    whatsapp_ddd: str | None
    whatsapp_number: str | None
    whatsapp_url: str | None
    sort_order: int | None
    is_active: bool
    whatsapp_clicks: int = 0

    model_config = ConfigDict(from_attributes=False)


class MarketplaceItemCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(None, max_length=8000)
    price_cents: int = Field(..., ge=0, le=999_999_999)
    currency: str = Field(default="BRL", min_length=3, max_length=8)
    image_url: str | None = Field(None, max_length=512)
    whatsapp_ddd: str | None = Field(None, max_length=4)
    whatsapp_number: str | None = Field(None, max_length=16)
    sort_order: int | None = None
    is_active: bool = True
    academy_id: UUID | None = Field(
        None,
        description="Obrigatório para administrador global; ignorado para gerente/professor.",
    )


class MarketplaceItemUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = Field(None, max_length=8000)
    price_cents: int | None = Field(None, ge=0, le=999_999_999)
    currency: str | None = Field(None, min_length=3, max_length=8)
    image_url: str | None = Field(None, max_length=512)
    whatsapp_ddd: str | None = Field(None, max_length=4)
    whatsapp_number: str | None = Field(None, max_length=16)
    sort_order: int | None = None
    is_active: bool | None = None


class MarketplaceItemStudentRead(BaseModel):
    id: UUID
    title: str
    description: str | None
    price_cents: int
    currency: str
    image_url: str | None
    whatsapp_url: str | None

    model_config = ConfigDict(from_attributes=False)
