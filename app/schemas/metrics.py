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


class WeeklyPanelLoginUserItem(BaseModel):
    """Usuário elegível (staff ou aluno) e seus dias de login no período (semana ISO ou intervalo)."""

    user_id: str
    name: Optional[str] = None
    email: str
    role: str
    academy_id: Optional[str] = None
    distinct_login_days_in_week: int
    login_days: list[date]


class TechniqueExecutionSummaryResponse(BaseModel):
    """Resumo de execuções de técnicas confirmadas (planejadas vs naturais)."""

    academy_id: Optional[str] = None
    before_training_count: int
    after_training_count: int
    total: int
    before_training_percent: float


class StudentAttentionItem(BaseModel):
    user_id: str
    name: Optional[str] = None
    email: str
    graduation: Optional[str] = None
    academy_id: Optional[str] = None
    academy_name: Optional[str] = None
    last_seen_at: Optional[datetime] = None
    days_absent: Optional[int] = None


class StudentsAttentionReportResponse(BaseModel):
    """Alunos que há mais tempo não aparecem em nenhuma aula."""

    academy_id: Optional[str] = None
    total_students: int
    students: list[StudentAttentionItem]


class MissionCompletionReportResponse(BaseModel):
    """Taxa de conclusão de missões: % de alunos que concluíram ≥1 missão no período."""

    academy_id: Optional[str] = None
    from_date: date
    to_date: date
    total_students: int
    users_completed: int
    completion_rate: float


class WeeklyPanelLoginsReportResponse(BaseModel):
    """
    Relatório de logins (staff e alunos), semana ISO ou intervalo customizado.

    - Escopo global quando academy_id é null.
    - Escopo por academia quando academy_id é informado.
    - week_start / week_end são as datas de início e fim do período (inclusive).
    """

    academy_id: Optional[str] = None
    week_start: date
    week_end: date
    eligible_users_count: int
    users_logged_at_least_once: int
    total_login_days: int = 0
    users: list[WeeklyPanelLoginUserItem]
