"""Dependência global: bloqueia (426) apps abaixo da versão mínima da plataforma.

Aplicada no api_router inteiro. Só age quando o cliente manda X-App-Version e X-App-Platform;
a web e versões antigas do app sem esses headers nunca são bloqueadas.
"""

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_version import APP_PLATFORM_HEADER, APP_VERSION_HEADER, normalize_platform
from app.core.exceptions import AppUpdateRequiredError
from app.database import get_db
from app.services.app_config_service import get_app_config, is_update_required

try:
    import sentry_sdk
except ImportError:  # pragma: no cover - sentry é opcional em ambiente local
    sentry_sdk = None

# Rotas que precisam responder mesmo a um app desatualizado: a própria config (o app
# descobre que precisa atualizar), health checks e os documentos legais.
_EXEMPT_PREFIXES = ("/app/config", "/health", "/metrics", "/legal")


async def enforce_min_app_version(request: Request, db: AsyncSession = Depends(get_db)) -> None:
    version = request.headers.get(APP_VERSION_HEADER)
    platform = normalize_platform(request.headers.get(APP_PLATFORM_HEADER))
    if not version or not platform:
        return

    if sentry_sdk is not None:
        sentry_sdk.set_tag("app.version", version)
        sentry_sdk.set_tag("app.platform", platform)

    if request.url.path.startswith(_EXEMPT_PREFIXES):
        return

    config = await get_app_config(db, platform)
    if is_update_required(config, version):
        raise AppUpdateRequiredError(
            min_version=config["min_version"],
            store_url=config.get("store_url"),
            update_message=config.get("update_message"),
        )
