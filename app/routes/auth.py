"""Autenticação: login e token JWT."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import UserRead
from app.services.user_service import get_user_by_email
from app.core.security import hash_password, verify_password, create_access_token
from app.core.auth_deps import get_current_user
from app.models import User

router = APIRouter()


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    db: Session = Depends(get_db),
):
    """Login com e-mail e senha. Retorna JWT para usar no header Authorization: Bearer <token>."""
    user = get_user_by_email(db, body.email)
    if not user or not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha inválidos.",
        )
    if not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha inválidos.",
        )
    token = create_access_token(user.id)
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    """Retorna o usuário autenticado (útil para o frontend saber quem está logado)."""
    return current_user
