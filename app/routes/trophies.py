"""Rotas de troféus: criar, listar por academia, galeria do usuário."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.trophy import TrophyCreate, TrophyRead, UserTrophyEarned
from app.services.trophy_service import (
    create_trophy,
    list_trophies_by_academy,
    list_user_trophies_with_earned,
)
from app.services.user_service import get_user

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
def trophy_create(body: TrophyCreate, db: Session = Depends(get_db)):
    """Cria troféu da academia (técnica, período, meta de execuções)."""
    trophy = create_trophy(
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
def trophy_list(
    academy_id: UUID = Query(..., description="ID da academia"),
    db: Session = Depends(get_db),
):
    """Lista troféus da academia."""
    return [_trophy_to_read(t) for t in list_trophies_by_academy(db, academy_id)]


@router.get("/user/{user_id}", response_model=list[UserTrophyEarned])
def trophy_user_gallery(user_id: UUID, db: Session = Depends(get_db)):
    """Galeria de troféus do usuário: troféus da academia dele com tier conquistado (ouro/prata/bronze)."""
    user = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    items = list_user_trophies_with_earned(db, user_id)
    return [UserTrophyEarned(**x) for x in items]
