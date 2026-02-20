"""Utilitários de segurança: hash de senha e JWT."""
import asyncio
from datetime import datetime, timezone, timedelta
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

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


def create_access_token(subject: str | UUID) -> str:
    """Cria JWT com sub = user_id (string)."""
    if isinstance(subject, UUID):
        subject = str(subject)
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    to_encode = {"sub": subject, "exp": expire}
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )


def decode_access_token(token: str) -> str | None:
    """Decodifica o JWT e retorna o sub (user_id) ou None se inválido."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload.get("sub")
    except JWTError:
        return None


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
