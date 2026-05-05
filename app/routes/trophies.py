"""Rotas de troféus: criar, listar por academia, galeria do usuário."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import ForbiddenError, TrophyNotFoundError
from app.core.list_pagination import MAX_LIST_LIMIT
from app.core.role_deps import require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.trophy import TrophyCreate, TrophyHomeSummaryResponse, TrophyRead, TrophyUpdate, UserTrophyEarned
from app.services.trophy_service import (
    create_trophy,
    get_trophy,
    get_trophy_home_summary,
    list_trophies_by_academy,
    list_user_trophies_with_earned,
    soft_delete_trophy,
    update_trophy,
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
        award_kind=getattr(t, "award_kind", "trophy"),
        min_duration_days=getattr(t, "min_duration_days", None),
        min_reward_level_to_unlock=getattr(t, "min_reward_level_to_unlock", 0),
        min_graduation_to_unlock=getattr(t, "min_graduation_to_unlock", None),
        max_count_per_opponent=getattr(t, "max_count_per_opponent", None),
        created_at=t.created_at,
    )


@router.post("", response_model=TrophyRead, status_code=201)
async def trophy_create(
    body: TrophyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria troféu ou medalha da academia."""
    verify_academy_access(current_user, str(body.academy_id) if body.academy_id else None)
    trophy = await create_trophy(
        db,
        academy_id=body.academy_id,
        technique_id=body.technique_id,
        name=body.name,
        start_date=body.start_date,
        end_date=body.end_date,
        target_count=body.target_count,
        award_kind=body.award_kind,
        min_duration_days=body.min_duration_days,
        min_reward_level_to_unlock=body.min_reward_level_to_unlock,
        min_graduation_to_unlock=body.min_graduation_to_unlock,
        max_count_per_opponent=body.max_count_per_opponent,
        audit_user_id=current_user.id,
    )
    return _trophy_to_read(trophy)


@router.get("", response_model=list[TrophyRead])
async def trophy_list(
    academy_id: UUID = Query(..., description="ID da academia"),
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT, description="Limite de resultados (máximo 50)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista troféus da academia."""
    verify_academy_access(current_user, str(academy_id))
    return [
        _trophy_to_read(t)
        for t in await list_trophies_by_academy(
            db,
            academy_id,
            limit=limit,
            offset=offset,
        )
    ]


@router.patch("/{trophy_id}", response_model=TrophyRead)
async def trophy_update(
    trophy_id: UUID,
    body: TrophyUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza troféu (edição livre; cliente pode avisar sobre impacto em conquistas)."""
    trophy = await get_trophy(db, trophy_id)
    if not trophy or trophy.deleted_at is not None:
        raise TrophyNotFoundError()
    verify_academy_access(current_user, str(trophy.academy_id))
    payload = body.model_dump(exclude_unset=True)
    updated = await update_trophy(db, trophy_id, payload, audit_user_id=current_user.id)
    return _trophy_to_read(updated)


@router.delete("/{trophy_id}", status_code=204)
async def trophy_delete(
    trophy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove troféu (soft delete: não aparece mais em listas/galeria)."""
    trophy = await get_trophy(db, trophy_id)
    if not trophy or trophy.deleted_at is not None:
        raise TrophyNotFoundError()
    verify_academy_access(current_user, str(trophy.academy_id))
    await soft_delete_trophy(db, trophy_id, audit_user_id=current_user.id)


@router.get("/me/home-summary", response_model=TrophyHomeSummaryResponse)
async def trophy_home_summary(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Resumo para os cards da home: conquistas recentes do usuário e feed da academia."""
    if not current_user.academy_id:
        return TrophyHomeSummaryResponse(my_earned_count=0, my_recent=[], academy_recent=[])
    data = await get_trophy_home_summary(db, current_user.id, current_user.academy_id)
    return TrophyHomeSummaryResponse(**data)


@router.get("/user/{user_id}", response_model=list[UserTrophyEarned])
async def trophy_user_gallery(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Galeria de troféus do usuário. Própria galeria: todos os itens. Galeria de outro: só conquistados e só se gallery_visible."""
    user = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador":
        verify_academy_access(current_user, str(user.academy_id) if user.academy_id else None)
    items = await list_user_trophies_with_earned(db, user_id)
    if current_user.id != user_id:
        if not user.gallery_visible:
            raise ForbiddenError("Esta galeria está privada.")
        items = [x for x in items if x.get("earned_tier") is not None]
    return [UserTrophyEarned(**x) for x in items]
