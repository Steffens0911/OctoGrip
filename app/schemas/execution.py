"""Schemas para execuções de técnica (gamificação)."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class ExecutionCreate(BaseModel):
    """Body do POST /executions. Informe exatamente um de mission_id ou lesson_id."""

    user_id: UUID
    mission_id: UUID | None = None
    lesson_id: UUID | None = None
    opponent_id: UUID
    usage_type: str = "after_training"  # before_training | after_training

    @model_validator(mode="after")
    def check_mission_or_lesson(self):
        if (self.mission_id is None) == (self.lesson_id is None):
            raise ValueError("Informe exatamente um de mission_id ou lesson_id.")
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
    opponent_name: str | None = None
    technique_name: str | None = None

    class Config:
        from_attributes = True


class ExecutionCreateResponse(BaseModel):
    """Resposta do POST /executions."""

    id: UUID
    status: str = "pending_confirmation"
    message: str


class ExecutionConfirmRequest(BaseModel):
    """Body do POST /executions/{id}/confirm."""

    outcome: str = Field(..., description="attempted_correctly | executed_successfully")
    user_id: UUID = Field(..., description="Quem confirma (deve ser o adversário)")


class ExecutionConfirmResponse(BaseModel):
    """Resposta do POST /executions/{id}/confirm."""

    id: UUID
    status: str = "confirmed"
    outcome: str
    points_awarded: int
    confirmed_at: datetime


class ExecutionRejectRequest(BaseModel):
    """Body do POST /executions/{id}/reject."""

    user_id: UUID = Field(..., description="Quem recusa (deve ser o adversário)")
    reason: str | None = Field(None, description="dont_remember = adversário não aceitou a posição")


class ExecutionRejectResponse(BaseModel):
    """Resposta do POST /executions/{id}/reject."""

    id: UUID
    status: str
