"""CRUD de técnicas (listagem por academia)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
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
def techniques_list(
    academy_id: UUID | None = Query(None, description="Filtra por academia"),
    db: Session = Depends(get_db),
):
    """Lista técnicas. academy_id obrigatório para listar (técnicas são por academia)."""
    if academy_id is None:
        raise HTTPException(status_code=400, detail="academy_id é obrigatório para listar técnicas.")
    return list_techniques(db, academy_id=academy_id)


@router.get("/{technique_id}", response_model=TechniqueRead)
def technique_get(
    technique_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto – retorna 404 se a técnica não for desta academia"),
    db: Session = Depends(get_db),
):
    """Retorna uma técnica por ID. Só retorna se pertencer à academia informada."""
    technique = get_technique(db, technique_id)
    if not technique or technique.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Técnica não encontrada.")
    return technique


@router.post("", response_model=TechniqueRead, status_code=201)
def technique_create(body: TechniqueCreate, db: Session = Depends(get_db)):
    """Cria uma nova técnica na academia. As posições devem pertencer à mesma academia."""
    try:
        return create_technique(
            db,
            academy_id=body.academy_id,
            name=body.name,
            from_position_id=body.from_position_id,
            to_position_id=body.to_position_id,
            slug=body.slug or None,
            description=body.description,
            video_url=body.video_url or None,
            base_points=body.base_points,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/{technique_id}", response_model=TechniqueRead)
def technique_update(
    technique_id: UUID,
    body: TechniqueUpdate,
    academy_id: UUID = Query(..., description="Academia do contexto – só permite editar técnicas desta academia"),
    db: Session = Depends(get_db),
):
    """Atualiza uma técnica (campos opcionais). Só permite se pertencer à academia informada."""
    technique = get_technique(db, technique_id)
    if not technique or technique.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Técnica não encontrada.")
    payload = body.model_dump(exclude_unset=True)
    try:
        updated = update_technique(db, technique_id, **payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    if not updated:
        raise HTTPException(status_code=404, detail="Técnica não encontrada.")
    return updated


@router.delete("/{technique_id}", status_code=204)
def technique_delete(
    technique_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto – só permite excluir técnicas desta academia"),
    db: Session = Depends(get_db),
):
    """Remove uma técnica. Só permite se pertencer à academia informada."""
    technique = get_technique(db, technique_id)
    if not technique or technique.academy_id != academy_id:
        raise HTTPException(status_code=404, detail="Técnica não encontrada.")
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
