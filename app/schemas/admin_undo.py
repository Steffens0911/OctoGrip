"""Respostas de acções administrativas de compensação (desfazer operação)."""
from __future__ import annotations

from pydantic import BaseModel, Field


class RevertExecutionResponse(BaseModel):
    execution_id: str
    user_id: str
    status: str
    message: str = Field(default="Confirmação revertida; pontos e nível do executor foram recalculados.")


class VoidMissionUsageResponse(BaseModel):
    mission_usage_id: str
    user_id: str
    message: str = Field(default="Registo de conclusão de missão removido; nível do utilizador foi recalculado.")
