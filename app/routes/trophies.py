"""Rotas de troféus: criar, listar por academia, galeria do usuário."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.role_deps import require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.trophy import TrophyCreate, TrophyRead, UserTrophyEarned
from app.services.trophy_service import (
    create_trophy,
    list_trophies_by_academy,
    list_user_trophies_with_earned,
)
from app.services.user_service import get_user_or_raise

router = APIRouter()


def _trophy_to_read(t):
    return TrophyRead(
        id=t.id,
        academy_id=t.academy_id,
        technique_id=t.technique_id,
        technique_name=t.technique.name if t.technique else None,
        name=t.name,
        start_date=t.start_date,
        end_date=t.end_date,
        target_count=t.target_count,
        created_at=t.created_at,
    )


@router.post("", response_model=TrophyRead, status_code=201)
async def trophy_create(
    body: TrophyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria troféu da academia."""
    verify_academy_access(current_user, str(body.academy_id) if body.academy_id else None)
    trophy = await create_trophy(
        db,
        academy_id=body.academy_id,
        technique_id=body.technique_id,
        name=body.name,
        start_date=body.start_date,
        end_date=body.end_date,
        target_count=body.target_count,
    )
    return _trophy_to_read(trophy)


@router.get("", response_model=list[TrophyRead])
async def trophy_list(
    academy_id: UUID = Query(..., description="ID da academia"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista troféus da academia."""
    verify_academy_access(current_user, str(academy_id))
    return [_trophy_to_read(t) for t in await list_trophies_by_academy(db, academy_id)]


@router.get("/user/{user_id}", response_model=list[UserTrophyEarned])
async def trophy_user_gallery(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Galeria de troféus do usuário."""
    user = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador":
        verify_academy_access(current_user, str(user.academy_id) if user.academy_id else None)
    items = await list_user_trophies_with_earned(db, user_id)
    return [UserTrophyEarned(**x) for x in items]
