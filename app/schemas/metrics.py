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
