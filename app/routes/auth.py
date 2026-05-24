"""Autenticação: login e token JWT com account lockout."""

import logging
import time
from datetime import UTC, datetime

from fastapi import APIRouter, Body, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.app_time import today_in_app_tz
from app.core.auth_deps import get_current_user
from app.core.exceptions import AppError
from app.core.metrics import security_events_total
from app.core.rate_limit import limiter
from app.core.security import create_access_token, verify_password
from app.database import get_db
from app.models import User
from app.models.user_login_day import UserLoginDay
from app.schemas.auth import DailyCheckinResponse, LoginRequest, TokenResponse
from app.schemas.user import MeUpdate, UserRead
from app.services.leveling_service import refresh_user_level
from app.services.login_streak_service import (
    apply_login_streak_bonus,
    user_read_with_login_streak,
)
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
    body: LoginRequest = Body(...),
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

    # Atualiza last_login_at, regista dia no fuso APP_TIMEZONE e aplica bónus de sequência se aplicável
    user.last_login_at = datetime.now(UTC)
    streak_bonus_points = await apply_login_streak_bonus(db, user, now=user.last_login_at)
    await db.commit()
    if streak_bonus_points > 0:
        await refresh_user_level(db, user.id)

    security_events_total.labels(event_type="login_success").inc()
    logger.info(
        "Login bem-sucedido",
        extra={
            "user_id": str(user.id),
            "email": body.email,
            "client_ip": client_ip,
            "role": user.role,
            "streak_bonus_points": streak_bonus_points,
        },
    )
    token = create_access_token(user.id)
    return TokenResponse(access_token=token, streak_bonus_points=streak_bonus_points)


@router.get("/me", response_model=UserRead)
async def me(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retorna o usuário autenticado (inclui login_streak_days)."""
    return await user_read_with_login_streak(db, current_user)


@router.patch("/me", response_model=UserRead)
async def patch_me(
    body: MeUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Atualiza preferências do usuário autenticado (ex.: galeria visível para outros)."""
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        return await user_read_with_login_streak(db, current_user)
    updated = await update_user(
        db,
        current_user.id,
        gallery_visible=payload.get("gallery_visible"),
        audit_user_id=current_user.id,
    )
    return await user_read_with_login_streak(db, updated if updated else current_user)


@router.post("/daily-checkin", response_model=DailyCheckinResponse)
async def daily_checkin(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Check-in diário silencioso.

    Registra o dia de uso no calendário do app (idempotente — pode ser chamado
    várias vezes no mesmo dia sem efeito colateral).  Avança a sequência de
    presença e concede pontos bônus nos marcos configurados (padrão: cada 7
    dias).  Usado pelo app Flutter para manter o streak mesmo sem novo login.
    """
    today = today_in_app_tz()

    # Verifica se já registrou hoje antes de qualquer write.
    existing = (
        await db.execute(
            select(UserLoginDay.login_day).where(
                UserLoginDay.user_id == current_user.id,
                UserLoginDay.login_day == today,
            )
        )
    ).one_or_none()
    already_checked_in = existing is not None

    streak_bonus_points = await apply_login_streak_bonus(db, current_user, now=None)
    await db.commit()
    if streak_bonus_points > 0:
        await refresh_user_level(db, current_user.id)

    logger.info(
        "daily_checkin",
        extra={
            "user_id": str(current_user.id),
            "already_checked_in": already_checked_in,
            "streak_bonus_points": streak_bonus_points,
        },
    )
    return DailyCheckinResponse(
        streak_bonus_points=streak_bonus_points,
        already_checked_in=already_checked_in,
    )
