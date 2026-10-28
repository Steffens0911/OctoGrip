"""Utilitários de segurança: hash de senha e JWT."""

import asyncio
import hashlib
import hmac
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings
from app.core.app_time import today_in_app_tz

if TYPE_CHECKING:
    from app.models import User

# pbkdf2_sha256: puro Python, funciona em python:slim (bcrypt precisa de libs no Docker)
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def hash_password_sync(plain: str) -> str:
    """Gera hash da senha (síncrono). Use apenas em scripts fora do event loop (ex.: seed)."""
    return pwd_context.hash(plain)


async def hash_password(plain: str) -> str:
    """Gera hash pbkdf2_sha256 da senha de forma assíncrona (não bloqueia o event loop)."""
    return await asyncio.to_thread(pwd_context.hash, plain)


async def verify_password(plain: str, hashed: str) -> bool:
    """Verifica se a senha em texto puro confere com o hash de forma assíncrona (não bloqueia o event loop)."""
    return await asyncio.to_thread(pwd_context.verify, plain, hashed)


def password_fingerprint(password_hash: str | None) -> str:
    """Impressão da senha atual gravada no token: trocar a senha invalida as sessões abertas.

    HMAC com o JWT_SECRET porque o payload do JWT é legível por quem tem o token.
    """
    digest = hmac.new(settings.JWT_SECRET.encode(), (password_hash or "").encode(), hashlib.sha256)
    return digest.hexdigest()[:16]


def create_access_token(user: "User") -> str:
    """Cria JWT com sub = user_id, validade de JWT_EXPIRE_MINUTES e a impressão da senha (pwv)."""
    now = datetime.now(UTC)
    to_encode: dict = {
        "sub": str(user.id),
        "iat": now,
        "exp": now + timedelta(minutes=settings.JWT_EXPIRE_MINUTES),
        "pwv": password_fingerprint(user.password_hash),
    }
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )


def decode_access_token(token: str) -> dict | None:
    """Decodifica o JWT (assinatura e validade) e retorna o payload, ou None se inválido ou vencido."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
    except JWTError:
        return None
    if not payload.get("sub") or payload.get("type") == "csrf":
        return None
    return payload


def token_matches_password(payload: dict, password_hash: str | None) -> bool:
    """Confere se o token foi emitido para a senha atual do usuário.

    Tokens antigos (sem ``pwv`` nem validade) valem só até JWT_LEGACY_TOKENS_UNTIL, prazo para o
    app trocá-los pelo POST /auth/refresh sem deslogar ninguém.
    """
    pwv = payload.get("pwv")
    if pwv is None:
        until = settings.JWT_LEGACY_TOKENS_UNTIL
        return until is not None and today_in_app_tz() <= until
    return hmac.compare_digest(str(pwv), password_fingerprint(password_hash))


def generate_csrf_token(user_id: str | UUID) -> str:
    """Gera um token CSRF baseado no user_id."""
    if isinstance(user_id, UUID):
        user_id = str(user_id)
    # Token CSRF simples baseado no user_id e secret
    # Em produção, considere usar uma implementação mais robusta
    return jwt.encode(
        {"sub": user_id, "type": "csrf"},
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )


def verify_csrf_token(token: str, user_id: str | UUID) -> bool:
    """Verifica se o token CSRF é válido para o usuário."""
    if isinstance(user_id, UUID):
        user_id = str(user_id)
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload.get("sub") == user_id and payload.get("type") == "csrf"
    except JWTError:
        return False
