from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ForbiddenError
from app.core.list_pagination import MAX_LIST_LIMIT
from app.core.role_deps import require_write_access
from app.database import get_db
from app.models import User
from app.schemas.marketplace_item import (
    MarketplaceItemAdminRead,
    MarketplaceItemCreate,
    MarketplaceItemUpdate,
    marketplace_item_admin_read_from_orm,
)
from app.services.marketplace_item_service import (
    create_marketplace_item,
    delete_marketplace_item,
    get_marketplace_item,
    list_marketplace_items_for_admin,
    update_marketplace_item,
)
from app.utils.marketplace_whatsapp import normalize_br_whatsapp_phone

router = APIRouter()


def _merge_whatsapp_into_patch(patch: dict) -> None:
    """Se DDD/número vierem no PATCH, normaliza para `whatsapp_phone` e remove chaves originais."""
    if "whatsapp_ddd" not in patch and "whatsapp_number" not in patch:
        return
    ddd = patch.pop("whatsapp_ddd", None)
    num = patch.pop("whatsapp_number", None)
    try:
        patch["whatsapp_phone"] = normalize_br_whatsapp_phone(ddd, num)
    except ValueError as e:
        raise AppError(str(e), status_code=400) from e


@router.get("", response_model=list[MarketplaceItemAdminRead])
async def marketplace_items_list(
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT, description="Limite de resultados (máximo 50)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Lista anúncios do marketplace (admin: todos; gerente/professor: só da sua academia)."""
    academy_filter: UUID | None = None
    if current_user.role != "administrador":
        if current_user.academy_id is None:
            return []
        academy_filter = current_user.academy_id
    rows = await list_marketplace_items_for_admin(
        db,
        academy_id=academy_filter,
        limit=limit,
        offset=offset,
    )
    return [marketplace_item_admin_read_from_orm(r) for r in rows]


@router.post("", response_model=MarketplaceItemAdminRead, status_code=201)
async def marketplace_item_create(
    body: MarketplaceItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    if current_user.role == "administrador":
        if body.academy_id is None:
            raise AppError("Administrador deve informar academy_id ao criar anúncio.", status_code=400)
        academy_id = body.academy_id
    else:
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia para criar anúncios.")
        academy_id = current_user.academy_id
    try:
        phone = normalize_br_whatsapp_phone(body.whatsapp_ddd, body.whatsapp_number)
    except ValueError as e:
        raise AppError(str(e), status_code=400) from e
    row = await create_marketplace_item(
        db,
        academy_id=academy_id,
        title=body.title,
        description=body.description,
        price_cents=body.price_cents,
        currency=body.currency,
        image_url=body.image_url,
        whatsapp_phone=phone,
        sort_order=body.sort_order,
        is_active=body.is_active,
        created_by_id=current_user.id,
        audit_user_id=current_user.id,
    )
    return marketplace_item_admin_read_from_orm(row)


@router.put("/{item_id}", response_model=MarketplaceItemAdminRead)
async def marketplace_item_update(
    item_id: UUID,
    body: MarketplaceItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    from app.core.exceptions import NotFoundError

    row = await get_marketplace_item(db, item_id)
    if not row:
        raise NotFoundError("Anúncio não encontrado.")
    if current_user.role != "administrador":
        if current_user.academy_id is None or row.academy_id != current_user.academy_id:
            raise ForbiddenError("Você não tem permissão para editar este anúncio.")
    patch = body.model_dump(exclude_unset=True)
    _merge_whatsapp_into_patch(patch)
    updated = await update_marketplace_item(db, item_id, patch, audit_user_id=current_user.id)
    assert updated is not None
    return marketplace_item_admin_read_from_orm(updated)


@router.delete("/{item_id}", status_code=204)
async def marketplace_item_delete(
    item_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    from app.core.exceptions import NotFoundError

    row = await get_marketplace_item(db, item_id)
    if not row:
        raise NotFoundError("Anúncio não encontrado.")
    if current_user.role != "administrador":
        if current_user.academy_id is None or row.academy_id != current_user.academy_id:
            raise ForbiddenError("Você não tem permissão para remover este anúncio.")
    ok = await delete_marketplace_item(db, item_id, audit_user_id=current_user.id)
    if not ok:
        raise NotFoundError("Anúncio não encontrado.")
    return None
