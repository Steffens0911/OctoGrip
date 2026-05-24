"""Schemas para autenticação (login e token)."""

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class LoginRequest(BaseModel):
    """Body do POST /auth/login."""

    model_config = ConfigDict(extra="forbid")

    email: EmailStr = Field(..., description="E-mail do usuário")
    password: str = Field(..., min_length=1, description="Senha do usuário")


class TokenResponse(BaseModel):
    """Resposta do login: access_token para enviar no header Authorization."""

    access_token: str
    token_type: str = "bearer"
    streak_bonus_points: int = Field(
        0,
        description="Pontos extra por sequência de login (múltiplos de 7 dias no calendário APP_TIMEZONE); 0 se não aplicou.",
    )


class DailyCheckinResponse(BaseModel):
    """Resposta do check-in diário silencioso (POST /auth/daily-checkin)."""

    streak_bonus_points: int = Field(
        0,
        description="Pontos concedidos por sequência (0 se ainda não era dia de bónus).",
    )
    already_checked_in: bool = Field(
        False,
        description="True se o usuário já tinha registado presença hoje (chamada duplicada no mesmo dia).",
    )
