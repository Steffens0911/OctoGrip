"""CRUD de posições (listagem para app + painel professor)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.position import PositionCreate, PositionRead, PositionUpdate
from app.services.position_service import (
    create_position,
    delete_position,
    get_position,
    list_positions,
    update_position,
)

router = APIRouter()


@router.get("", response_model=list[PositionRead])
def positions_list(db: Session = Depends(get_db)):
    """Lista posições (para o app escolher ao reportar dificuldade e para o professor)."""
    return list_positions(db)


@router.get("/{position_id}", response_model=PositionRead)
def position_get(position_id: UUID, db: Session = Depends(get_db)):
    """Retorna uma posição por ID."""
    position = get_position(db, position_id)
    if not position:
        raise HTTPException(status_code=404, detail="Posição não encontrada.")
    return position


@router.post("", response_model=PositionRead, status_code=201)
def position_create(body: PositionCreate, db: Session = Depends(get_db)):
    """Cria uma nova posição."""
    try:
        return create_position(db, name=body.name, slug=body.slug or None, description=body.description)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Já existe uma posição com este nome ou slug. Escolha outro.",
        )


@router.put("/{position_id}", response_model=PositionRead)
def position_update(
    position_id: UUID,
    body: PositionUpdate,
    db: Session = Depends(get_db),
):
    """Atualiza uma posição (campos opcionais)."""
    position = get_position(db, position_id)
    if not position:
        raise HTTPException(status_code=404, detail="Posição não encontrada.")
    payload = body.model_dump(exclude_unset=True)
    updated = update_position(
        db,
        position_id,
        name=payload.get("name"),
        slug=payload.get("slug"),
        description=payload.get("description"),
    )
    return updated


@router.delete("/{position_id}", status_code=204)
def position_remove(position_id: UUID, db: Session = Depends(get_db)):
    """Remove uma posição (falha se houver técnicas vinculadas)."""
    try:
        if not delete_position(db, position_id):
            raise HTTPException(status_code=404, detail="Posição não encontrada.")
        return None
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Não é possível excluir: existem técnicas vinculadas a esta posição.",
        )
