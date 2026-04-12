"""Schemas para registo de token FCM e avisos por academia."""

from typing import Literal

from pydantic import BaseModel, Field


class PushTokenRegister(BaseModel):
    """Corpo para registar ou atualizar o token do dispositivo atual."""

    token: str = Field(..., min_length=10, max_length=4096)
    platform: Literal["android", "ios", "web"] = "android"


class AcademyPushNotifyRequest(BaseModel):
    """Aviso enviado aos utilizadores da academia com app e token registados."""

    title: str = Field(..., min_length=1, max_length=120)
    body: str = Field(..., min_length=1, max_length=2000)


class AcademyPushNotifyResponse(BaseModel):
    """Resumo do envio FCM."""

    target_tokens: int = Field(..., description="Número de tokens distintos alvo")
    sent: int = Field(..., description="Envios aceites pela API FCM")
    failed: int = Field(..., description="Falhas ou tokens inválidos removidos")
