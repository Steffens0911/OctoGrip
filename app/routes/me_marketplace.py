from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.list_pagination import MAX_LIST_LIMIT
from app.database import get_db
from app.models import User
from app.schemas.marketplace_item import (
    MarketplaceItemStudentRead,
    marketplace_item_student_read_from_orm,
)
from app.services.marketplace_item_service import (
    increment_whatsapp_click,
    list_marketplace_items_for_user,
)

router = APIRouter()


@router.get("/marketplace_items", response_model=list[MarketplaceItemStudentRead])
async def my_marketplace_items(
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT, description="Limite por página"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista anúncios ativos da academia do usuário (vazia se não houver academia)."""
    rows = await list_marketplace_items_for_user(
        db,
        user=current_user,
        limit=limit,
        offset=offset,
    )
    return [marketplace_item_student_read_from_orm(r) for r in rows]


@router.post("/marketplace_items/{item_id}/whatsapp_click", status_code=204)
async def record_marketplace_whatsapp_click(
    item_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registra que o aluno tocou em 'Chamar no WhatsApp' neste anúncio."""
    await increment_whatsapp_click(db, item_id)
