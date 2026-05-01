"""Cache in-memory com suporte opcional a Redis para cenários multi-worker."""
import asyncio
import json
import time
from typing import Any
from uuid import UUID

from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.config import settings


def _json_default(value: Any) -> str:
    if isinstance(value, UUID):
        return str(value)
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


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


class AsyncCache:
    """Cache assíncrono com backend Redis opcional e fallback in-memory."""

    def __init__(
        self,
        *,
        default_ttl: int = 60,
        max_size: int = 1024,
        namespace: str = "app_cache:",
        redis_url: str | None = None,
    ):
        self._namespace = namespace
        self._memory = TTLCache(default_ttl=default_ttl, max_size=max_size)
        self._redis: Redis | None = None
        self._prefix_versions: dict[str, int] = {}
        self._versions_lock = asyncio.Lock()
        if redis_url:
            self._redis = Redis.from_url(redis_url, encoding="utf-8", decode_responses=True)

    def _key(self, key: str) -> str:
        return f"{self._namespace}{key}"

    def _prefix_version_key(self, prefix: str) -> str:
        return self._key(f"__pv__:{prefix}")

    async def get_prefix_version(self, prefix: str) -> int:
        async with self._versions_lock:
            cached = self._prefix_versions.get(prefix)
            if cached is not None:
                return cached
            if self._redis is not None:
                try:
                    raw = await self._redis.get(self._prefix_version_key(prefix))
                    ver = int(raw) if raw is not None else 0
                    self._prefix_versions[prefix] = ver
                    return ver
                except (RedisError, ValueError):
                    pass
            self._prefix_versions[prefix] = 0
            return 0

    async def bump_prefix_version(self, prefix: str) -> int:
        async with self._versions_lock:
            current = self._prefix_versions.get(prefix, 0)
            new_ver = current + 1
            if self._redis is not None:
                try:
                    new_ver = int(await self._redis.incr(self._prefix_version_key(prefix)))
                except RedisError:
                    pass
            self._prefix_versions[prefix] = new_ver
            return new_ver

    async def versioned_key(self, prefix: str, key_suffix: str) -> str:
        version = await self.get_prefix_version(prefix)
        return f"{prefix}v{version}:{key_suffix}"

    async def get(self, key: str) -> Any | None:
        if self._redis is not None:
            try:
                raw = await self._redis.get(self._key(key))
                if raw is None:
                    return None
                return json.loads(raw)
            except (RedisError, json.JSONDecodeError):
                return await self._memory.get(key)
        return await self._memory.get(key)

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        effective_ttl = ttl or self._memory._default_ttl
        await self._memory.set(key, value, ttl=effective_ttl)
        if self._redis is not None:
            try:
                payload = json.dumps(value, default=_json_default)
                await self._redis.setex(self._key(key), effective_ttl, payload)
            except (RedisError, TypeError, ValueError):
                return

    async def invalidate(self, key: str) -> None:
        await self._memory.invalidate(key)
        if self._redis is not None:
            try:
                await self._redis.delete(self._key(key))
            except RedisError:
                return

    async def invalidate_prefix(self, prefix: str) -> int:
        removed = await self._memory.invalidate_prefix(prefix)
        if self._redis is None:
            return removed
        try:
            keys: list[str] = []
            async for redis_key in self._redis.scan_iter(match=self._key(f"{prefix}*"), count=500):
                keys.append(redis_key)
            if keys:
                removed += int(await self._redis.unlink(*keys))
            return removed
        except RedisError:
            return removed

    async def clear(self) -> None:
        await self._memory.clear()
        async with self._versions_lock:
            self._prefix_versions.clear()
        if self._redis is None:
            return
        try:
            keys: list[str] = []
            async for redis_key in self._redis.scan_iter(match=self._key("*"), count=1000):
                keys.append(redis_key)
            if keys:
                await self._redis.unlink(*keys)
        except RedisError:
            return


app_cache = AsyncCache(
    default_ttl=60,
    max_size=2048,
    namespace="app_cache:",
    redis_url=settings.REDIS_URL,
)

techniques_cache = TTLCache(default_ttl=120, max_size=512)

positions_cache = TTLCache(default_ttl=120, max_size=512)
