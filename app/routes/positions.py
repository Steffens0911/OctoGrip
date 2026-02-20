"""CRUD de posições (listagem por academia, app e painel)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.role_deps import require_read_access, require_write_access
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


@router.get("", response_model=list[PositionRead])
def positions_list(
    academy_id: UUID | None = Query(None, description="Filtra por academia"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Lista posições. academy_id obrigatório para listar (posições são por academia). Admin, gerente, professor ou supervisor."""
    if academy_id is None:
        raise HTTPException(status_code=400, detail="academy_id é obrigatório para listar posições.")
    return list_positions(db, academy_id=academy_id)


@router.get("/{position_id}", response_model=PositionRead)
def position_get(
    position_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto – retorna 404 se a posição não for desta academia"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Retorna uma posição por ID. Só retorna se pertencer à academia informada. Admin, gerente, professor ou supervisor."""
    position = get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Posição não encontrada.")
    return position


@router.post("", response_model=PositionRead, status_code=201)
def position_create(
    body: PositionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria uma nova posição na academia. Admin, gerente ou professor."""
    try:
        return create_position(
            db, academy_id=body.academy_id, name=body.name, slug=body.slug or None, description=body.description
        )
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
    academy_id: UUID = Query(..., description="Academia do contexto – só permite editar posições desta academia"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza uma posição (campos opcionais). Só permite se pertencer à academia informada. Admin, gerente ou professor."""
    position = get_position(db, position_id)
    if not position or position.academy_id != academy_id:
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
def position_remove(
    position_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto – só permite excluir posições desta academia"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove uma posição (falha se houver técnicas vinculadas). Só permite se pertencer à academia informada. Admin, gerente ou professor."""
    position = get_position(db, position_id)
    if not position or position.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Posição não encontrada.")
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
