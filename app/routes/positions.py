"""CRUD de posições (listagem por academia, app e painel)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.position import PositionCreate, PositionRead, PositionUpdate
from app.services.position_service import create_position, delete_position, get_position, list_positions, update_position

router = APIRouter()


@router.get("", response_model=list[PositionRead])
async def positions_list(academy_id: UUID | None = Query(None), db: AsyncSession = Depends(get_db)):
    if academy_id is None:
        raise HTTPException(status_code=400, detail="academy_id é obrigatório para listar posições.")
    return await list_positions(db, academy_id=academy_id)


@router.get("/{position_id}", response_model=PositionRead)
async def position_get(position_id: UUID, academy_id: UUID = Query(...), db: AsyncSession = Depends(get_db)):
    position = await get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Posição não encontrada.")
    return position


@router.post("", response_model=PositionRead, status_code=201)
async def position_create(body: PositionCreate, db: AsyncSession = Depends(get_db)):
    try:
        return await create_position(db, academy_id=body.academy_id, name=body.name, slug=body.slug or None, description=body.description)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Já existe uma posição com este nome ou slug.")


@router.put("/{position_id}", response_model=PositionRead)
async def position_update(position_id: UUID, body: PositionUpdate, academy_id: UUID = Query(...), db: AsyncSession = Depends(get_db)):
    position = await get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Posição não encontrada.")
    payload = body.model_dump(exclude_unset=True)
    return await update_position(db, position_id, name=payload.get("name"), slug=payload.get("slug"), description=payload.get("description"))


@router.delete("/{position_id}", status_code=204)
async def position_remove(position_id: UUID, academy_id: UUID = Query(...), db: AsyncSession = Depends(get_db)):
    position = await get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Posição não encontrada.")
    try:
        if not await delete_position(db, position_id):
            raise HTTPException(status_code=404, detail="Posição não encontrada.")
        return None
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Não é possível excluir: existem técnicas vinculadas a esta posição.")
