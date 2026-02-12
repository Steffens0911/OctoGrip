from pydantic import BaseModel


class UsageMetricsResponse(BaseModel):
    """Métricas básicas de uso (conclusões de lição)."""

    total_completions: int
    completions_last_7_days: int
    unique_users_completed: int
