"""Cache in-memory com TTL para endpoints read-heavy. Substitível por Redis em produção."""
import asyncio
import time
from typing import Any


class TTLCache:
    """Cache simples com TTL por chave. Thread-safe via asyncio.Lock."""

    def __init__(self, default_ttl: int = 60, max_size: int = 1024):
        self._store: dict[str, tuple[Any, float]] = {}
        self._default_ttl = default_ttl
        self._max_size = max_size
        self._lock = asyncio.Lock()

    async def get(self, key: str) -> Any | None:
        async with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            value, expires_at = entry
            if time.monotonic() > expires_at:
                del self._store[key]
                return None
            return value

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        async with self._lock:
            if len(self._store) >= self._max_size:
                self._evict_expired()
            if len(self._store) >= self._max_size:
                oldest_key = min(self._store, key=lambda k: self._store[k][1])
                del self._store[oldest_key]
            expires_at = time.monotonic() + (ttl or self._default_ttl)
            self._store[key] = (value, expires_at)

    async def invalidate(self, key: str) -> None:
        async with self._lock:
            self._store.pop(key, None)

    async def invalidate_prefix(self, prefix: str) -> int:
        """Invalida todas as chaves com o prefixo dado."""
        async with self._lock:
            keys_to_remove = [k for k in self._store if k.startswith(prefix)]
            for k in keys_to_remove:
                del self._store[k]
            return len(keys_to_remove)

    async def clear(self) -> None:
        async with self._lock:
            self._store.clear()

    def _evict_expired(self) -> None:
        now = time.monotonic()
        expired = [k for k, (_, exp) in self._store.items() if now > exp]
        for k in expired:
            del self._store[k]


app_cache = TTLCache(default_ttl=60, max_size=2048)

techniques_cache = TTLCache(default_ttl=120, max_size=512)

positions_cache = TTLCache(default_ttl=120, max_size=512)
