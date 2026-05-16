from __future__ import annotations

from datetime import date

from pydantic import BaseModel


class TechniqueImpact(BaseModel):
    technique_name: str
    students_completed: int
    total_students: int
    completion_pct: float
    missions_count: int


class AtRiskStudent(BaseModel):
    id: str
    name: str
    days_inactive: int
    risk_level: str  # "alert" (>14 dias), "warning" (7-14 dias)


class ProfessorImpactResponse(BaseModel):
    week_start: date
    week_end: date
    students_reached: int
    total_students: int
    completion_rate: float
    completion_rate_delta: float | None
    techniques: list[TechniqueImpact]
    at_risk_students: list[AtRiskStudent]
    total_missions_in_academy: int
    total_completions_all_time: int
