from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class UsageMetricsResponse(BaseModel):
    """Métricas básicas de uso (conclusões de lição) e retenção (PB-02)."""

    total_completions: int
    completions_last_7_days: int
    unique_users_completed: int
    # PB-02: métricas de retenção (MissionUsage)
    before_training_count: int = 0
    after_training_count: int = 0
    before_training_percent: float = 0.0


class EngagementPeriodMetrics(BaseModel):
    """Métricas de engajamento para um período específico (semana ou mês)."""

    start_date: date
    end_date: date
    total_students: int
    active_students: int
    active_rate: float


class EngagementReportResponse(BaseModel):
    """
    Relatório de engajamento (% de alunos ativos) em visão semanal e mensal.

    - Local (academy_id informado).
    - Geral (todas as academias) quando academy_id é null.
    """

    academy_id: Optional[str] = None
    weekly: EngagementPeriodMetrics
    monthly: EngagementPeriodMetrics


class ActiveStudentItem(BaseModel):
    """Aluno ativo dentro da janela de 7 dias (login)."""

    id: str
    name: Optional[str] = None
    email: str
    academy_id: Optional[str] = None
    academy_name: Optional[str] = None
    graduation: Optional[str] = None
    last_login_at: Optional[datetime] = None


class ActiveStudentsReportResponse(BaseModel):
    """
    Relatório detalhado de alunos ativos (lista de alunos) em uma janela móvel de 7 dias.

    - Local (academy_id informado) ou global (academy_id null).
    """

    academy_id: Optional[str] = None
    start_date: date
    end_date: date
    total_students: int
    active_students: int
    active_rate: float
    students: list[ActiveStudentItem]
