"""CRUD de posições (listagem por academia, app e painel)."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ConflictError, ForbiddenError, PositionNotFoundError
from app.core.role_deps import require_read_access, require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.position import PositionCreate, PositionRead, PositionUpdate
from app.services.position_service import (
    create_position,
    delete_position,
    get_position,
    list_positions,
    update_position,
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
    raise AppError("academy_id é obrigatório para listar posições.")


@router.get("", response_model=list[PositionRead])
async def positions_list(
    academy_id: UUID | None = Query(None, description="Filtra por academia"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Lista posições por academia."""
    resolved = _resolve_academy_id(current_user, academy_id)
    return await list_positions(db, academy_id=resolved)


@router.get("/{position_id}", response_model=PositionRead)
async def position_get(
    position_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Retorna uma posição por ID."""
    verify_academy_access(current_user, str(academy_id))
    position = await get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise PositionNotFoundError()
    return position


@router.post("", response_model=PositionRead, status_code=201)
async def position_create(
    body: PositionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria uma nova posição na academia."""
    verify_academy_access(current_user, str(body.academy_id) if body.academy_id else None)
    try:
        return await create_position(
            db, academy_id=body.academy_id, name=body.name, slug=body.slug or None, description=body.description
        )
    except IntegrityError:
        await db.rollback()
        raise ConflictError("Já existe uma posição com este nome ou slug. Escolha outro.")


@router.put("/{position_id}", response_model=PositionRead)
async def position_update(
    position_id: UUID,
    body: PositionUpdate,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza uma posição."""
    verify_academy_access(current_user, str(academy_id))
    position = await get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise PositionNotFoundError()
    payload = body.model_dump(exclude_unset=True)
    updated = await update_position(
        db,
        position_id,
        name=payload.get("name"),
        slug=payload.get("slug"),
        description=payload.get("description"),
    )
    return updated


@router.delete("/{position_id}", status_code=204)
async def position_remove(
    position_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove uma posição."""
    position = await get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise PositionNotFoundError()
    try:
        if not await delete_position(db, position_id):
            raise PositionNotFoundError()
        return None
    except IntegrityError:
        await db.rollback()
        raise ConflictError("Não é possível excluir: existem técnicas vinculadas a esta posição.")
