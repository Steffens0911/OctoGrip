"""Utilitários de segurança: hash de senha e JWT."""
from datetime import datetime, timezone, timedelta
from uuid import UUID

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

# pbkdf2_sha256: puro Python, funciona em python:slim (bcrypt precisa de libs no Docker)
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def hash_password(plain: str) -> str:
    """Gera hash bcrypt da senha."""
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """Verifica se a senha em texto puro confere com o hash."""
    return pwd_context.verify(plain, hashed)


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
