"""Limites de pontuação para vídeo diário e missões da semana (gamificação)."""

MIN_REWARD_POINTS: int = 10
MAX_REWARD_POINTS: int = 50


def clamp_reward_points(value: int) -> int:
    """Garante valor no intervalo [MIN_REWARD_POINTS, MAX_REWARD_POINTS]."""
    return max(MIN_REWARD_POINTS, min(MAX_REWARD_POINTS, value))
