"""Schemas de consentimento LGPD e direitos do titular."""

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

ConsentType = Literal["terms", "privacy", "biometric"]


class ConsentRecordRequest(BaseModel):
    """Registra a concessão (ou revogação) de um consentimento."""

    consent_type: ConsentType
    granted: bool = True
    document_version: str | None = Field(
        default=None,
        max_length=64,
        description="Versão do documento aceito. Se omitida, usa a versão vigente do servidor.",
    )


class ConsentStatusItem(BaseModel):
    """Estado atual de um tipo de consentimento para o utilizador."""

    consent_type: ConsentType
    granted: bool = Field(description="Estado vigente (linha mais recente).")
    document_version: str | None = Field(description="Versão registrada no último aceite.")
    current_version: str | None = Field(description="Versão vigente do documento no servidor.")
    up_to_date: bool = Field(description="True se concedido e na versão vigente.")
    updated_at: datetime | None = Field(description="Quando o estado atual foi registrado.")


class ConsentStatusResponse(BaseModel):
    """Estado de todos os consentimentos rastreados."""

    items: list[ConsentStatusItem]


class DataExportResponse(BaseModel):
    """Cópia dos dados pessoais do titular (LGPD, art. 18, II/V)."""

    generated_at: datetime
    profile: dict[str, Any]
    consents: list[dict[str, Any]]
    related_data: dict[str, Any]


class AccountDeletionResponse(BaseModel):
    """Confirmação de atendimento ao direito de eliminação/anonimização."""

    status: Literal["anonymized"]
    user_id: str
    message: str
