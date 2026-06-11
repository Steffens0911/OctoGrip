"""Cache do endpoint /me/training_stats (chave por usuário).

Invalidado quando algo que altera as estatísticas do próprio aluno acontece:
confirmação de execução, check-in de presença e vídeo diário concluído.
Métricas da academia (médias top-10, rankings) expiram apenas pelo TTL —
invalidar a academia inteira a cada evento seria caro e desnecessário.
"""

from uuid import UUID

from app.core.cache import app_cache

TRAINING_STATS_TTL_SEC = 90
_TRAINING_STATS_PREFIX = "training_stats:"


def training_stats_cache_key(user_id: UUID) -> str:
    return f"{_TRAINING_STATS_PREFIX}{user_id}"


async def invalidate_training_stats_cache(user_id: UUID | None) -> None:
    if user_id is None:
        return
    await app_cache.invalidate(training_stats_cache_key(user_id))
