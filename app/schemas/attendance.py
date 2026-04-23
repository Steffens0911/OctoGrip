from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class AttendanceSessionCreate(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    expires_in_minutes: int | None = Field(
        default=20,
        ge=1,
        le=180,
        description="Tempo total (min) em que a sessão permanece ativa se não for encerrada manualmente.",
    )


class AttendanceSessionRead(BaseModel):
    id: UUID
    academy_id: UUID | None
    created_by_user_id: UUID
    status: str
    title: str | None = None
    starts_at: datetime
    ends_at: datetime | None = None
    expires_at: datetime | None = None
    present_count: int = 0


class AttendanceQrPayloadResponse(BaseModel):
    payload: str
    expires_at: datetime


class AttendanceScanRequest(BaseModel):
    payload: str = Field(..., min_length=10, description="Payload lido do QR (sid/iat/exp/nonce/sig).")


class AttendanceRecordRead(BaseModel):
    id: UUID
    session_id: UUID
    user_id: UUID
    checked_in_at: datetime
    method: str


class AttendanceUserSummaryResponse(BaseModel):
    user_id: UUID
    from_dt: datetime
    to_dt: datetime
    present_count: int
    last_seen_at: datetime | None = None

