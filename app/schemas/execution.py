"""Schemas para execuções de técnica (gamificação)."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


class ExecutionCreate(BaseModel):
    """Body do POST /executions. user_id vem do token. Informe exatamente um de mission_id, lesson_id ou technique_id."""

    model_config = ConfigDict(extra="forbid")

    mission_id: UUID | None = None
    lesson_id: UUID | None = None
    technique_id: UUID | None = None
    academy_id: UUID | None = None  # obrigatório quando technique_id é informado
    opponent_id: UUID
    usage_type: str = "after_training"  # before_training | after_training

    @model_validator(mode="after")
    def check_source(self):
        filled = sum(1 for x in (self.mission_id, self.lesson_id, self.technique_id) if x is not None)
        if filled != 1:
            raise ValueError("Informe exatamente um de mission_id, lesson_id ou technique_id.")
        if self.technique_id is not None and self.academy_id is None:
            raise ValueError("Quando technique_id for informado, academy_id é obrigatório.")
        return self


class ExecutionRead(BaseModel):
    """Execução para leitura (lista e detalhe)."""

    id: UUID
    user_id: UUID
    mission_id: UUID | None = None
    lesson_id: UUID | None = None
    opponent_id: UUID
    usage_type: str
    status: str
    outcome: str | None = None
    points_awarded: int | None = None
    created_at: datetime
    confirmed_at: datetime | None = None
    confirmed_by: UUID | None = None
    # Dados anexados (opcional)
    executor_name: str | None = None
    executor_graduation: str | None = None
    opponent_name: str | None = None
    opponent_graduation: str | None = None
    technique_name: str | None = None

    class Config:
        from_attributes = True


class ExecutionCreateResponse(BaseModel):
    """Resposta do POST /executions."""

    id: UUID
    status: str = "pending_confirmation"
    message: str


class ExecutionConfirmRequest(BaseModel):
    """Body do POST /executions/{id}/confirm. Quem confirma vem do token (adversário)."""

    model_config = ConfigDict(extra="forbid")

    outcome: str = Field(..., description="attempted_correctly | executed_successfully")


class ExecutionConfirmResponse(BaseModel):
    """Resposta do POST /executions/{id}/confirm."""

    id: UUID
    status: str = "confirmed"
    outcome: str
    points_awarded: int
    confirmed_at: datetime


class ExecutionRejectRequest(BaseModel):
    """Body do POST /executions/{id}/reject. Quem recusa vem do token (adversário)."""

    model_config = ConfigDict(extra="forbid")

    reason: str | None = Field(None, description="dont_remember = adversário não aceitou a posição")


class ExecutionRejectResponse(BaseModel):
    """Resposta do POST /executions/{id}/reject."""

    id: UUID
    status: str
