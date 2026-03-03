"""CRUD de parceiros por academia (gestor e admin)."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ForbiddenError, PartnerNotFoundError
from app.core.role_deps import require_read_access, require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.partner import PartnerCreate, PartnerRead, PartnerUpdate
from app.services.partner_service import (
    create_partner,
    delete_partner,
    get_partner,
    list_partners,
    update_partner,
)

router = APIRouter()


def _resolve_academy_id(current_user: User, academy_id: UUID | None) -> UUID:
    """Resolve academy_id: admin exige explícito, demais usam sua própria."""
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))
        return academy_id
    if current_user.role != "administrador":
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia.")
        return current_user.academy_id
    raise AppError("academy_id é obrigatório para listar parceiros.")


@router.get("", response_model=list[PartnerRead])
async def partners_list(
    academy_id: UUID | None = Query(None, description="Filtra por academia"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Lista parceiros da academia."""
    resolved = _resolve_academy_id(current_user, academy_id)
    return await list_partners(db, academy_id=resolved)


@router.get("/{partner_id}", response_model=PartnerRead)
async def partner_get(
    partner_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Retorna um parceiro por ID."""
    verify_academy_access(current_user, str(academy_id))
    partner = await get_partner(db, partner_id)
    if not partner or partner.academy_id != academy_id:
        raise PartnerNotFoundError()
    return partner


@router.post("", response_model=PartnerRead, status_code=201)
async def partner_create(
    body: PartnerCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria um novo parceiro na academia."""
    verify_academy_access(current_user, str(body.academy_id))
    return await create_partner(
        db,
        academy_id=body.academy_id,
        name=body.name,
        description=body.description,
        url=body.url,
        logo_url=body.logo_url,
    )


@router.put("/{partner_id}", response_model=PartnerRead)
async def partner_update(
    partner_id: UUID,
    body: PartnerUpdate,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza um parceiro."""
    verify_academy_access(current_user, str(academy_id))
    partner = await get_partner(db, partner_id)
    if not partner or partner.academy_id != academy_id:
        raise PartnerNotFoundError()
    payload = body.model_dump(exclude_unset=True)
    updated = await update_partner(
        db,
        partner_id,
        name=payload.get("name"),
        description=payload.get("description"),
        url=payload.get("url"),
        logo_url=payload.get("logo_url"),
    )
    return updated


@router.delete("/{partner_id}", status_code=204)
async def partner_remove(
    partner_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove um parceiro."""
    verify_academy_access(current_user, str(academy_id))
    partner = await get_partner(db, partner_id)
    if not partner or partner.academy_id != academy_id:
        raise PartnerNotFoundError()
    if not await delete_partner(db, partner_id):
        raise PartnerNotFoundError()
    return None
