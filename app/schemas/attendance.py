from __future__ import annotations

from datetime import date, datetime
from typing import Literal
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


class AttendanceManualCheckinRequest(BaseModel):
    """Correção de presença: professor/gestor adiciona aluno sem QR."""

    user_id: UUID


class AttendanceRecordRead(BaseModel):
    id: UUID
    session_id: UUID
    user_id: UUID
    checked_in_at: datetime
    method: str
    face_recognition: bool = False


class AttendanceUserSummaryResponse(BaseModel):
    user_id: UUID
    from_dt: datetime
    to_dt: datetime
    present_count: int
    last_seen_at: datetime | None = None


class AttendanceSessionStatRead(BaseModel):
    """Estatística de uma sessão (frequência do professor — modo minhas sessões)."""

    id: UUID
    title: str | None = None
    starts_at: datetime
    ends_at: datetime | None = None
    status: str
    present_count: int


class AttendanceStudentStatRead(BaseModel):
    """Frequência de um aluno no período (presenças / total de sessões da academia)."""

    user_id: UUID
    email: str
    name: str | None = None
    graduation: str | None = None
    present_count: int
    total_sessions: int
    attendance_rate: float = Field(..., ge=0.0, le=1.0, description="present_count / total_sessions (0 se sem sessões).")
    last_seen_at: datetime | None = None


class AttendanceRecordWithSessionRead(BaseModel):
    id: UUID
    session_id: UUID
    session_title: str | None = None
    session_starts_at: datetime
    checked_in_at: datetime
    method: str
    face_recognition: bool = False


class AttendanceRankingEntryRead(BaseModel):
    position: int
    student_id: UUID
    name: str
    avatar_url: str | None = None
    belt: str | None = None
    total_checkins: int
    attendance_percentage: int = Field(..., ge=0, le=100)
    position_change: int | None = None


class AttendanceMyPositionRead(BaseModel):
    position: int
    total_checkins: int
    attendance_percentage: int = Field(..., ge=0, le=100)
    position_change: int | None = None


class AttendanceRankingRead(BaseModel):
    month: str | None = None
    period_kind: Literal["month", "quarter", "year", "custom"]
    period_label: str
    period_start: date
    period_end: date
    ranking: list[AttendanceRankingEntryRead]
    my_position: AttendanceMyPositionRead | None = None


class AttendanceStudentDetailRead(BaseModel):
    user_id: UUID
    email: str
    name: str | None = None
    graduation: str | None = None
    present_count: int
    total_sessions: int
    attendance_rate: float = Field(..., ge=0.0, le=1.0)
    last_seen_at: datetime | None = None
    records: list[AttendanceRecordWithSessionRead]


class AttendancePeriodBucketRead(BaseModel):
    """Bucket de presenças (semana ou mês) para gráfico do aluno."""

    period_start: date
    period_end: date
    label: str
    present_count: int


class AttendanceMyStatsRead(BaseModel):
    """Frequência do utilizador logado na sua academia (período + histórico paginado)."""

    from_date: datetime
    to_date: datetime
    bucket: Literal["week", "month"]
    total_sessions: int
    total_checkins: int
    percentage: float = Field(..., ge=0.0, le=1.0, description="No período: total_checkins / total_sessions.")
    last_seen_at: datetime | None = None
    lifetime_total_sessions: int = Field(..., description="Total de sessões da academia desde sempre.")
    lifetime_total_checkins: int = Field(..., description="Presenças do utilizador na academia desde sempre.")
    lifetime_percentage: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Desde o início: lifetime_total_checkins / lifetime_total_sessions.",
    )
    checkins_by_period: list[AttendancePeriodBucketRead]
    history: list[AttendanceRecordWithSessionRead]
    history_total: int
    history_limit: int
    history_offset: int

