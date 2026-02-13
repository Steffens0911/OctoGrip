from datetime import date
from uuid import UUID

from pydantic import BaseModel


class MissionCreate(BaseModel):
    """T-01: Criação de missão pelo professor (painel web)."""

    lesson_id: UUID
    start_date: date
    end_date: date
    level: str = "beginner"
    theme: str | None = None
    academy_id: UUID | None = None


class MissionUpdate(BaseModel):
    """Atualização parcial de missão (editar)."""

    lesson_id: UUID | None = None
    start_date: date | None = None
    end_date: date | None = None
    level: str | None = None
    theme: str | None = None
    academy_id: UUID | None = None
    is_active: bool | None = None


class MissionRead(BaseModel):
    """Leitura de uma missão (lista/detalhe)."""

    id: UUID
    lesson_id: UUID
    start_date: date
    end_date: date
    level: str
    theme: str | None
    academy_id: UUID | None
    is_active: bool = True

    class Config:
        from_attributes = True


class MissionTodayResponse(BaseModel):
    """Resposta pronta para o frontend: missão do dia com dados montados."""

    lesson_id: UUID
    mission_title: str
    lesson_title: str
    description: str
    video_url: str
    position_name: str
    technique_name: str
    objective: str | None = None
    estimated_duration_seconds: int | None = None
    weekly_theme: str | None = None
    is_review: bool = False
