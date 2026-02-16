"""CRUD de técnicas (listagem e painel admin)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.technique import TechniqueCreate, TechniqueRead, TechniqueUpdate
from app.services.technique_service import (
    create_technique,
    delete_technique,
    get_technique,
    list_techniques,
    update_technique,
)

router = APIRouter()


@router.get("", response_model=list[TechniqueRead])
def techniques_list(db: Session = Depends(get_db)):
    """Lista técnicas ordenadas por nome (para escolher ao criar/editar lição)."""
    return list_techniques(db)


@router.get("/{technique_id}", response_model=TechniqueRead)
def technique_get(technique_id: UUID, db: Session = Depends(get_db)):
    """Retorna uma técnica por ID."""
    technique = get_technique(db, technique_id)
    if not technique:
        raise HTTPException(status_code=404, detail="Técnica não encontrada.")
    return technique


@router.post("", response_model=TechniqueRead, status_code=201)
def technique_create(body: TechniqueCreate, db: Session = Depends(get_db)):
    """Cria uma nova técnica."""
    return create_technique(
        db,
        name=body.name,
        from_position_id=body.from_position_id,
        to_position_id=body.to_position_id,
        slug=body.slug or None,
        description=body.description,
        video_url=body.video_url or None,
        base_points=body.base_points,
    )


@router.put("/{technique_id}", response_model=TechniqueRead)
def technique_update(
    technique_id: UUID,
    body: TechniqueUpdate,
    db: Session = Depends(get_db),
):
    """Atualiza uma técnica (campos opcionais)."""
    payload = body.model_dump(exclude_unset=True)
    updated = update_technique(db, technique_id, **payload)
    if not updated:
        raise HTTPException(status_code=404, detail="Técnica não encontrada.")
    return updated


@router.delete("/{technique_id}", status_code=204)
def technique_delete(technique_id: UUID, db: Session = Depends(get_db)):
    """Remove uma técnica."""
    try:
        if not delete_technique(db, technique_id):
            raise HTTPException(status_code=404, detail="Técnica não encontrada.")
        return None
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Não é possível excluir: existem lições ou missões vinculadas a esta técnica.",
        )
