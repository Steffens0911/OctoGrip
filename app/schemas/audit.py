"""Schemas para histórico e restauração via auditoria."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field


class AuditLogItem(BaseModel):
    id: UUID
    user_id: UUID | None
    action: str
    entity: str
    entity_id: UUID
    old_data: dict[str, Any] | None
    new_data: dict[str, Any] | None
    created_at: datetime

    model_config = {"from_attributes": True}


class AuditHistoryResponse(BaseModel):
    items: list[AuditLogItem]
    total: int
    limit: int = Field(..., ge=1, le=200)
    offset: int = Field(..., ge=0)
    order: Literal["asc", "desc"] = "asc"


class RestoreResponse(BaseModel):
    restored: bool
    mode: str
    entity: str
    id: str
    from_audit_log_id: str | None = None
