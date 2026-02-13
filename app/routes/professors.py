"""CRUD de professores (seção professor)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Professor
from app.schemas.professor import ProfessorCreate, ProfessorRead, ProfessorUpdate
from app.services.professor_service import (
    create_professor,
    delete_professor,
    get_professor,
    list_professors,
    update_professor,
)

router = APIRouter()


@router.get("", response_model=list[ProfessorRead])
def professors_list(
    academy_id: UUID | None = Query(None, description="Filtrar por academia"),
    db: Session = Depends(get_db),
):
    """Lista professores (opcionalmente por academia)."""
    return list_professors(db, academy_id=academy_id)


@router.get("/{professor_id}", response_model=ProfessorRead)
def professor_get(professor_id: UUID, db: Session = Depends(get_db)):
    """Retorna um professor por ID."""
    professor = get_professor(db, professor_id)
    if not professor:
        raise HTTPException(status_code=404, detail="Professor não encontrado.")
    return professor


@router.post("", response_model=ProfessorRead, status_code=201)
def professor_create(body: ProfessorCreate, db: Session = Depends(get_db)):
    """Cria um professor (e-mail único)."""
    existing = db.query(Professor).filter(Professor.email == body.email).first()
    if existing:
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")
    return create_professor(
        db,
        name=body.name,
        email=body.email,
        academy_id=body.academy_id,
    )


@router.patch("/{professor_id}", response_model=ProfessorRead)
def professor_update(
    professor_id: UUID,
    body: ProfessorUpdate,
    db: Session = Depends(get_db),
):
    """Atualiza um professor."""
    payload = body.model_dump(exclude_unset=True)
    updated = update_professor(
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
def professor_delete(professor_id: UUID, db: Session = Depends(get_db)):
    """Remove um professor."""
    if not delete_professor(db, professor_id):
        raise HTTPException(status_code=404, detail="Professor não encontrado.")
    return None
