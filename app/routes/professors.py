"""CRUD de professores (seção professor)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.professor import ProfessorCreate, ProfessorRead, ProfessorUpdate
from app.services.professor_service import (
    create_professor,
    delete_professor,
    get_professor,
    get_professor_by_email,
    list_professors,
    update_professor,
)

router = APIRouter()


@router.get("", response_model=list[ProfessorRead])
async def professors_list(
    academy_id: UUID | None = Query(None, description="Filtrar por academia"),
    db: AsyncSession = Depends(get_db),
):
    return await list_professors(db, academy_id=academy_id)


@router.get("/{professor_id}", response_model=ProfessorRead)
async def professor_get(professor_id: UUID, db: AsyncSession = Depends(get_db)):
    professor = await get_professor(db, professor_id)
    if not professor:
        raise HTTPException(status_code=404, detail="Professor não encontrado.")
    return professor


@router.post("", response_model=ProfessorRead, status_code=201)
async def professor_create(body: ProfessorCreate, db: AsyncSession = Depends(get_db)):
    existing = await get_professor_by_email(db, body.email)
    if existing:
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")
    return await create_professor(
        db,
        name=body.name,
        email=body.email,
        academy_id=body.academy_id,
    )


@router.patch("/{professor_id}", response_model=ProfessorRead)
async def professor_update(
    professor_id: UUID,
    body: ProfessorUpdate,
    db: AsyncSession = Depends(get_db),
):
    payload = body.model_dump(exclude_unset=True)
    updated = await update_professor(
        db,
        professor_id,
        name=payload.get("name"),
        email=payload.get("email"),
        academy_id=payload.get("academy_id"),
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Professor não encontrado.")
    return updated


@router.delete("/{professor_id}", status_code=204)
async def professor_delete(professor_id: UUID, db: AsyncSession = Depends(get_db)):
    if not await delete_professor(db, professor_id):
        raise HTTPException(status_code=404, detail="Professor não encontrado.")
    return None
