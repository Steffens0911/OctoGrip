"""Autenticação: login e token JWT."""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.auth_deps import get_current_user
from app.core.rate_limit import limiter
from app.core.security import verify_password, create_access_token
from app.database import get_db
from app.models import User
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import UserRead
from app.services.user_service import get_user_by_email

router = APIRouter()


@router.post("/login", response_model=TokenResponse)
@limiter.limit(settings.LOGIN_RATE_LIMIT)
async def login(
    request: Request,
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Login com e-mail e senha. Retorna JWT para usar no header Authorization: Bearer <token>."""
    user = await get_user_by_email(db, body.email)
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
async def me(current_user: User = Depends(get_current_user)):
    """Retorna o usuário autenticado (útil para o frontend saber quem está logado)."""
    return current_user
