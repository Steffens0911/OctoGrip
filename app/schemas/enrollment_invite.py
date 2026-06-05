"""Schemas Pydantic para convite de auto-cadastro e solicitações pendentes."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, field_validator


class InvitePublicInfo(BaseModel):
    """Informações da academia retornadas ao aluno quando acessa o link público."""

    academy_id: uuid.UUID
    academy_name: str
    token: str


class EnrollmentSubmit(BaseModel):
    """Dados enviados pelo aluno no formulário público de cadastro."""

    name: str
    email: EmailStr
    phone: str | None = None
    graduation: str | None = None
    password: str
    confirm_password: str

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Nome é obrigatório.")
        return v

    @field_validator("confirm_password")
    @classmethod
    def passwords_match(cls, v: str, info) -> str:
        if "password" in info.data and v != info.data["password"]:
            raise ValueError("As senhas não coincidem.")
        return v

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("A senha deve ter no mínimo 6 caracteres.")
        return v


class EnrollmentSubmitResponse(BaseModel):
    """Confirmação retornada após envio bem-sucedido."""

    message: str


class PendingEnrollmentRead(BaseModel):
    """Solicitação pendente exibida para o gestor/professor."""

    id: uuid.UUID
    academy_id: uuid.UUID
    name: str
    email: str
    phone: str | None
    graduation: str | None
    status: str
    rejection_reason: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class EnrollmentDecision(BaseModel):
    """Decisão do gestor: aprovar ou rejeitar."""

    action: str  # "approve" | "reject"
    rejection_reason: str | None = None

    @field_validator("action")
    @classmethod
    def valid_action(cls, v: str) -> str:
        if v not in ("approve", "reject"):
            raise ValueError("action deve ser 'approve' ou 'reject'.")
        return v


class InviteRead(BaseModel):
    """Token de convite retornado para o gestor gerar QR/link."""

    token: str
    is_active: bool

    model_config = {"from_attributes": True}
