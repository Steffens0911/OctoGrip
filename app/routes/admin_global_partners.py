"""CRUD de parceiros globais (admin global)."""
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError
from app.core.role_deps import require_admin
from app.database import get_db
from app.models import User
from app.schemas.global_partner import (
    GlobalPartnerCreate,
    GlobalPartnerRead,
    GlobalPartnerUpdate,
)
from app.services.global_partner_service import (
    create_global_partner,
    delete_global_partner,
    get_global_partner,
    list_global_partners,
    update_global_partner,
)

router = APIRouter()


@router.get("/global_partners", response_model=list[GlobalPartnerRead])
async def admin_global_partners_list(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    return await list_global_partners(db)


@router.get("/global_partners/{partner_id}", response_model=GlobalPartnerRead)
async def admin_global_partner_get(
    partner_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    partner = await get_global_partner(db, partner_id)
    if not partner:
        raise NotFoundError("Parceiro global não encontrado.")
    return partner


@router.post("/global_partners", response_model=GlobalPartnerRead, status_code=201)
async def admin_global_partner_create(
    body: GlobalPartnerCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    return await create_global_partner(
        db,
        name=body.name,
        description=body.description,
        logo_url=body.logo_url,
        offer_text=body.offer_text,
        external_url=body.external_url,
        featured_order=body.featured_order,
        is_active=body.is_active,
        audit_user_id=current_user.id,
    )


@router.put("/global_partners/{partner_id}", response_model=GlobalPartnerRead)
async def admin_global_partner_update(
    partner_id: UUID,
    body: GlobalPartnerUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    payload = body.model_dump(exclude_unset=True)
    updated = await update_global_partner(
        db,
        partner_id,
        name=payload.get("name"),
        description=payload.get("description"),
        logo_url=payload.get("logo_url"),
        offer_text=payload.get("offer_text"),
        external_url=payload.get("external_url"),
        featured_order=payload.get("featured_order"),
        is_active=payload.get("is_active"),
        audit_user_id=current_user.id,
    )
    if not updated:
        raise NotFoundError("Parceiro global não encontrado.")
    return updated


@router.delete("/global_partners/{partner_id}", status_code=204)
async def admin_global_partner_delete(
    partner_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    if not await delete_global_partner(db, partner_id, audit_user_id=current_user.id):
        raise NotFoundError("Parceiro global não encontrado.")
    return None
