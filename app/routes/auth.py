"""Autenticação: login e token JWT com account lockout."""
import logging
import time

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.auth_deps import get_current_user
from app.core.exceptions import AppError
from app.core.metrics import security_events_total
from app.core.rate_limit import limiter
from app.core.security import verify_password, create_access_token
from app.database import get_db
from app.models import User
from app.schemas.auth import LoginRequest, TokenResponse
from app.schemas.user import MeUpdate, UserRead
from app.services.user_service import get_user_by_email, update_user

logger = logging.getLogger(__name__)

router = APIRouter()

_failed_attempts: dict[str, list[float]] = {}

_MAX_ATTEMPTS = settings.ACCOUNT_LOCKOUT_ATTEMPTS
_LOCKOUT_SECONDS = settings.ACCOUNT_LOCKOUT_MINUTES * 60


def _check_lockout(email: str) -> None:
    """Verifica se o e-mail está bloqueado por muitas tentativas falhas."""
    key = email.strip().lower()
    attempts = _failed_attempts.get(key, [])
    now = time.monotonic()
    recent = [t for t in attempts if now - t < _LOCKOUT_SECONDS]
    _failed_attempts[key] = recent
    if len(recent) >= _MAX_ATTEMPTS:
        security_events_total.labels(event_type="account_locked").inc()
        logger.warning("Conta bloqueada por tentativas excessivas", extra={"email": email})
        raise AppError(
            f"Conta temporariamente bloqueada. Tente novamente em {settings.ACCOUNT_LOCKOUT_MINUTES} minutos.",
            status_code=429,
        )


def _record_failed_attempt(email: str) -> None:
    key = email.strip().lower()
    _failed_attempts.setdefault(key, []).append(time.monotonic())


def _clear_failed_attempts(email: str) -> None:
    key = email.strip().lower()
    _failed_attempts.pop(key, None)


@router.post("/login", response_model=TokenResponse)
@limiter.limit(settings.LOGIN_RATE_LIMIT)
async def login(
    request: Request,
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Login com e-mail e senha. Retorna JWT."""
    client_ip = request.client.host if request.client else "unknown"

    _check_lockout(body.email)

    user = await get_user_by_email(db, body.email)
    if not user or not user.password_hash:
        _record_failed_attempt(body.email)
        security_events_total.labels(event_type="login_failed_user_not_found").inc()
        logger.warning(
            "Login falhado: usuário não encontrado",
            extra={"email": body.email, "client_ip": client_ip, "reason": "user_not_found"},
        )
        raise AppError("E-mail ou senha inválidos.", status_code=401)

    if not await verify_password(body.password, user.password_hash):
        _record_failed_attempt(body.email)
        security_events_total.labels(event_type="login_failed_invalid_password").inc()
        logger.warning(
            "Login falhado: senha incorreta",
            extra={"email": body.email, "user_id": str(user.id), "client_ip": client_ip, "reason": "invalid_password"},
        )
        raise AppError("E-mail ou senha inválidos.", status_code=401)

    _clear_failed_attempts(body.email)
    security_events_total.labels(event_type="login_success").inc()
    logger.info(
        "Login bem-sucedido",
        extra={"user_id": str(user.id), "email": body.email, "client_ip": client_ip, "role": user.role},
    )
    token = create_access_token(user.id)
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserRead)
async def me(current_user: User = Depends(get_current_user)):
    """Retorna o usuário autenticado."""
    return current_user


@router.patch("/me", response_model=UserRead)
async def patch_me(
    body: MeUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Atualiza preferências do usuário autenticado (ex.: galeria visível para outros)."""
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        return current_user
    updated = await update_user(
        db,
        current_user.id,
        gallery_visible=payload.get("gallery_visible"),
    )
    return updated if updated else current_user
