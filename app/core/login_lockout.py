"""Bloqueio temporário de login após tentativas com senha errada.

A contagem é por e-mail + IP: errar a senha de outra pessoa a partir de outro lugar não trava
a conta dela, e o rate limit por IP do POST /auth/login segura quem tenta muitas contas.
Fica no Redis para valer entre os workers do uvicorn; sem Redis, cai para a memória do processo.
"""

import logging
import time

from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.config import settings

logger = logging.getLogger(__name__)

# Teto de chaves em memória (fallback): sem ele, e-mails inventados cresceriam sem limite.
_MEMORY_MAX_KEYS = 10_000


class LoginLockout:
    def __init__(self, *, max_attempts: int, window_seconds: int, storage_uri: str):
        self._max_attempts = max_attempts
        self._window_seconds = window_seconds
        self._memory: dict[str, list[float]] = {}
        self._redis: Redis | None = None
        if storage_uri.startswith(("redis://", "rediss://")):
            self._redis = Redis.from_url(
                storage_uri,
                decode_responses=True,
                socket_connect_timeout=0.5,
                socket_timeout=0.5,
            )

    @staticmethod
    def _key(email: str, ip: str) -> str:
        return f"login_fail:{email.strip().lower()}|{ip}"

    def _recent_in_memory(self, key: str) -> list[float]:
        now = time.monotonic()
        recent = [t for t in self._memory.get(key, []) if now - t < self._window_seconds]
        if recent:
            self._memory[key] = recent
        else:
            self._memory.pop(key, None)
        return recent

    async def is_locked(self, email: str, ip: str) -> bool:
        key = self._key(email, ip)
        if self._redis is not None:
            try:
                count = await self._redis.get(key)
                return int(count or 0) >= self._max_attempts
            except RedisError:
                logger.warning("Redis indisponível no bloqueio de login; usando memória", exc_info=True)
        return len(self._recent_in_memory(key)) >= self._max_attempts

    async def record_failure(self, email: str, ip: str) -> None:
        key = self._key(email, ip)
        if self._redis is not None:
            try:
                async with self._redis.pipeline(transaction=True) as pipe:
                    pipe.incr(key)
                    # Janela fixa a partir da primeira falha: NX não renova o prazo a cada erro.
                    pipe.expire(key, self._window_seconds, nx=True)
                    await pipe.execute()
                return
            except RedisError:
                logger.warning("Redis indisponível no bloqueio de login; usando memória", exc_info=True)
        recent = self._recent_in_memory(key)
        if key not in self._memory and len(self._memory) >= _MEMORY_MAX_KEYS:
            oldest = min(self._memory, key=lambda k: self._memory[k][-1])
            del self._memory[oldest]
        self._memory[key] = [*recent, time.monotonic()]

    async def clear(self, email: str, ip: str) -> None:
        key = self._key(email, ip)
        self._memory.pop(key, None)
        if self._redis is not None:
            try:
                await self._redis.delete(key)
            except RedisError:
                logger.warning("Redis indisponível ao limpar bloqueio de login", exc_info=True)


login_lockout = LoginLockout(
    max_attempts=settings.ACCOUNT_LOCKOUT_ATTEMPTS,
    window_seconds=settings.ACCOUNT_LOCKOUT_MINUTES * 60,
    storage_uri=settings.rate_limit_storage_uri,
)
