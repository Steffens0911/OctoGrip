"""Schemas para autenticação (login e token)."""
from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    """Body do POST /auth/login."""

    email: str = Field(..., min_length=1, max_length=255)
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    """Resposta do login: access_token para enviar no header Authorization."""

    access_token: str
    token_type: str = "bearer"
