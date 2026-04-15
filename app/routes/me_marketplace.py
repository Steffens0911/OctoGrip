from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.database import get_db
from app.models import User
from app.schemas.marketplace_item import (
    MarketplaceItemStudentRead,
    marketplace_item_student_read_from_orm,
)
from app.services.marketplace_item_service import list_marketplace_items_for_user

router = APIRouter()


@router.get("/marketplace_items", response_model=list[MarketplaceItemStudentRead])
async def my_marketplace_items(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista anúncios ativos da academia do usuário (vazia se não houver academia)."""
    rows = await list_marketplace_items_for_user(db, user=current_user)
    return [marketplace_item_student_read_from_orm(r) for r in rows]
