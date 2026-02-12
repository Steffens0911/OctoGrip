from pydantic import BaseModel


class MissionTodayResponse(BaseModel):
    """Resposta pronta para o frontend: missão do dia com dados montados."""

    mission_title: str
    lesson_title: str
    description: str
    video_url: str
    position_name: str
    technique_name: str
    objective: str | None = None
    estimated_duration_seconds: int | None = None
