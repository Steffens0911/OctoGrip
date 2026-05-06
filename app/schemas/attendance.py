from __future__ import annotations

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


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


class QrTokenOut(BaseModel):
    token: str
    expires_at: datetime
    short_code: str


class QrScanIn(BaseModel):
    token: str = Field(..., min_length=5)


class AttendanceManualCheckinRequest(BaseModel):
    """Correção de presença: professor/gestor adiciona aluno(s) sem QR."""

    user_id: UUID | None = Field(default=None, description="Um aluno (contrato legado).")
    student_ids: list[UUID] | None = Field(
        default=None,
        description="Vários alunos na mesma requisição.",
    )

    @model_validator(mode="after")
    def user_id_or_student_ids(self) -> AttendanceManualCheckinRequest:
        has_uid = self.user_id is not None
        has_sids = self.student_ids is not None
        if has_uid and has_sids:
            raise ValueError("Informe apenas user_id ou student_ids, não ambos.")
        if not has_uid and not has_sids:
            raise ValueError("Informe user_id ou student_ids.")
        if has_sids and len(self.student_ids or ()) == 0:
            raise ValueError("student_ids não pode ser uma lista vazia.")
        return self


class AttendanceRecordRead(BaseModel):
    id: UUID
    session_id: UUID
    user_id: UUID
    checked_in_at: datetime
    method: str
    face_recognition: bool = False
    added_manually: bool = False


class AttendanceManualBatchResponse(BaseModel):
    records: list[AttendanceRecordRead]


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

