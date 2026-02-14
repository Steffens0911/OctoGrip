from datetime import date
from uuid import UUID

from pydantic import BaseModel


class MissionCreate(BaseModel):
    """T-01: Criação de missão pelo professor (painel web). Missão = técnica + período."""

    technique_id: UUID
    start_date: date
    end_date: date
    level: str = "beginner"
    theme: str | None = None
    academy_id: UUID | None = None


class MissionUpdate(BaseModel):
    """Atualização parcial de missão (editar)."""

    technique_id: UUID | None = None
    start_date: date | None = None
    end_date: date | None = None
    level: str | None = None
    theme: str | None = None
    academy_id: UUID | None = None
    is_active: bool | None = None


class MissionRead(BaseModel):
    """Leitura de uma missão (lista/detalhe)."""

    id: UUID
    technique_id: UUID
    start_date: date
    end_date: date
    level: str
    theme: str | None
    academy_id: UUID | None
    is_active: bool = True

    class Config:
        from_attributes = True


class MissionTodayResponse(BaseModel):
    """Resposta da missão do dia: técnica + posição. mission_id para conclusão por missão."""

    mission_id: UUID | None = None
    technique_id: UUID
    lesson_id: UUID | None = None
    mission_title: str
    lesson_title: str
    description: str
    video_url: str = ""
    position_name: str
    technique_name: str
    objective: str | None = None
    estimated_duration_seconds: int | None = None
    weekly_theme: str | None = None
    is_review: bool = False
    already_completed: bool = False


class MissionWeekSlotResponse(BaseModel):
    """Um slot da semana (seg-ter, qua-qui, sex-dom) com a missão opcional."""

    period_label: str  # "Missão 1", "Missão 2", "Missão 3"
    mission: MissionTodayResponse | None = None


class MissionWeekResponse(BaseModel):
    """Lista das 3 missões semanais para exibição ao aluno."""

    entries: list[MissionWeekSlotResponse]  # sempre 3 itens, na ordem seg-ter, qua-qui, sex-dom
