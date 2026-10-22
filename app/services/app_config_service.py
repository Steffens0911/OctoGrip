"""Configuração do app por plataforma e registro da versão usada por cada usuário."""

import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_version import is_version_below
from app.core.cache import TTLCache
from app.models import AppConfig, User

logger = logging.getLogger(__name__)

# A checagem de versão mínima roda em toda requisição com X-App-Version: cache curto em memória.
# Com vários workers, uma alteração no admin leva até 60 s para valer em todos.
_CONFIG_TTL_SECONDS = 60
_config_cache = TTLCache(default_ttl=_CONFIG_TTL_SECONDS, max_size=16)

# Versão já registrada há menos que isso não gera UPDATE (evita escrita a cada requisição).
_RECORD_INTERVAL = timedelta(days=1)


def _default_config(platform: str) -> dict:
    return {
        "platform": platform,
        "min_version": "0.0.0",
        "latest_version": "0.0.0",
        "update_message": None,
        "store_url": None,
        "feature_flags": {},
    }


def _config_to_dict(row: AppConfig) -> dict:
    return {
        "platform": row.platform,
        "min_version": row.min_version,
        "latest_version": row.latest_version,
        "update_message": row.update_message,
        "store_url": row.store_url,
        "feature_flags": row.feature_flags or {},
    }


async def get_app_config(db: AsyncSession, platform: str) -> dict:
    """Config da plataforma (cache de 60 s); plataforma sem linha → padrões que não bloqueiam ninguém."""
    cached = await _config_cache.get(platform)
    if cached is not None:
        return cached
    row = await db.get(AppConfig, platform)
    config = _config_to_dict(row) if row else _default_config(platform)
    await _config_cache.set(platform, config)
    return config


async def list_app_configs(db: AsyncSession) -> list[dict]:
    rows = (await db.execute(select(AppConfig).order_by(AppConfig.platform))).scalars().all()
    return [_config_to_dict(r) for r in rows]


async def upsert_app_config(db: AsyncSession, platform: str, values: dict) -> dict:
    row = await db.get(AppConfig, platform)
    if row is None:
        row = AppConfig(**_default_config(platform))
        db.add(row)
    for key, value in values.items():
        setattr(row, key, value)
    await db.commit()
    await db.refresh(row)
    await _config_cache.invalidate(platform)
    return _config_to_dict(row)


async def clear_app_config_cache() -> None:
    await _config_cache.clear()


def is_update_required(config: dict, app_version: str | None) -> bool:
    return is_version_below(app_version, config.get("min_version"))


async def record_app_version(db: AsyncSession, user: User, app_version: str, platform: str | None) -> None:
    """Guarda a versão do app do usuário; só escreve se mudou ou se o último registro tem mais de 1 dia.

    Falha aqui nunca derruba a requisição: a versão é dado de acompanhamento, não de negócio.
    """
    now = datetime.now(UTC)
    unchanged = user.last_app_version == app_version and user.last_app_platform == platform
    if unchanged and user.last_app_seen_at and now - user.last_app_seen_at < _RECORD_INTERVAL:
        return
    try:
        user.last_app_version = app_version
        user.last_app_platform = platform
        user.last_app_seen_at = now
        await db.commit()
    except Exception:
        user_id = str(user.id)
        logger.warning("Falha ao registrar versão do app", exc_info=True, extra={"user_id": user_id})
        await db.rollback()
        # O rollback expira o objeto; recarrega para a rota seguir usando o usuário (sem lazy load async).
        await db.refresh(user)


async def app_version_distribution(db: AsyncSession, days: int) -> list[dict]:
    """Usuários ativos nos últimos ``days`` dias agrupados por plataforma e versão (mais usados primeiro)."""
    since = datetime.now(UTC) - timedelta(days=days)
    stmt = (
        select(User.last_app_platform, User.last_app_version, func.count(User.id))
        .where(User.last_app_seen_at >= since, User.last_app_version.is_not(None))
        .group_by(User.last_app_platform, User.last_app_version)
        .order_by(func.count(User.id).desc())
    )
    rows = (await db.execute(stmt)).all()
    return [{"platform": p, "version": v, "users": n} for p, v, n in rows]
