"""CRUD de usuários (painel desenvolvedores)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.services.user_service import create_user, delete_user, get_user, list_users, update_user

router = APIRouter()


@router.get("", response_model=list[UserRead])
def users_list(db: Session = Depends(get_db)):
    """Lista usuários."""
    return list_users(db)


@router.get("/{user_id}", response_model=UserRead)
def user_get(user_id: UUID, db: Session = Depends(get_db)):
    user = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return user


@router.post("", response_model=UserRead, status_code=201)
def user_create(body: UserCreate, db: Session = Depends(get_db)):
    """Cria um usuário (email único)."""
    existing = db.query(User).filter(User.email == body.email).first()
    if existing:
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")
    return create_user(db, email=body.email, name=body.name, academy_id=body.academy_id)


@router.patch("/{user_id}", response_model=UserRead)
def user_update(user_id: UUID, body: UserUpdate, db: Session = Depends(get_db)):
    payload = body.model_dump(exclude_unset=True)
    updated = update_user(
        db,
        user_id,
        name=payload.get("name"),
        academy_id=payload.get("academy_id"),
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return updated


@router.delete("/{user_id}", status_code=204)
def user_delete(user_id: UUID, db: Session = Depends(get_db)):
    try:
        if not delete_user(db, user_id):
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return None
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Não é possível excluir: existem registros vinculados (progresso, missões, feedback).",
        )
