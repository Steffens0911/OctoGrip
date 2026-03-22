from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.points_limits import MAX_REWARD_POINTS, MIN_REWARD_POINTS


class MissionCreate(BaseModel):
    """T-01: Criação de missão. Missão = lição (ou técnica) + período."""

    model_config = ConfigDict(extra="forbid")

    technique_id: UUID
    lesson_id: UUID | None = None
    start_date: date
    end_date: date
    level: str = "beginner"
    theme: str | None = None
    academy_id: UUID | None = None
    multiplier: int = Field(default=MIN_REWARD_POINTS, ge=MIN_REWARD_POINTS, le=MAX_REWARD_POINTS)

    @model_validator(mode="after")
    def end_after_start(self):
        if self.end_date < self.start_date:
            raise ValueError("end_date deve ser igual ou posterior a start_date")
        return self


class MissionUpdate(BaseModel):
    """Atualização parcial de missão (editar)."""

    model_config = ConfigDict(extra="forbid")

    technique_id: UUID | None = None
    lesson_id: UUID | None = None
    slot_index: int | None = None
    start_date: date | None = None
    end_date: date | None = None
    level: str | None = None
    theme: str | None = None
    academy_id: UUID | None = None
    is_active: bool | None = None
    multiplier: int | None = Field(None, ge=MIN_REWARD_POINTS, le=MAX_REWARD_POINTS)


class MissionRead(BaseModel):
    """Leitura de uma missão (lista/detalhe)."""

    id: UUID
    technique_id: UUID
    technique_name: str | None = None
    lesson_id: UUID | None = None
    slot_index: int | None = None
    start_date: date | None = None
    end_date: date | None = None
    level: str
    theme: str | None
    academy_id: UUID | None
    is_active: bool = True
    multiplier: int = MIN_REWARD_POINTS

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
    multiplier: int = MIN_REWARD_POINTS


class MissionWeekSlotResponse(BaseModel):
    """Um slot da semana (seg-ter, qua-qui, sex-dom) com a missão opcional."""

    period_label: str  # "Missão 1", "Missão 2", "Missão 3"
    mission: MissionTodayResponse | None = None


class MissionWeekResponse(BaseModel):
    """Lista das 3 missões semanais para exibição ao aluno."""

    entries: list[MissionWeekSlotResponse]  # sempre 3 itens, na ordem seg-ter, qua-qui, sex-dom
