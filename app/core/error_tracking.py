"""
Configuração opcional de Sentry para error tracking.
"""

import logging
import os

logger = logging.getLogger(__name__)

_sentry_initialized = False

# Chaves sensíveis que nunca devem ir para o Sentry (LGPD: auth + biometria)
_SCRUB_KEYS = frozenset({
    "authorization",
    "password",
    "token",
    "secret",
    "cookie",
    "embedding",
    "face_embedding",
    "image_data",
    "biometric",
    "jwt",
    "x-api-key",
})


def _scrub_dict(data: dict) -> dict:
    """Remove recursivamente chaves sensíveis de dicts."""
    result = {}
    for k, v in data.items():
        if k.lower() in _SCRUB_KEYS:
            result[k] = "[Filtered]"
        elif isinstance(v, dict):
            result[k] = _scrub_dict(v)
        else:
            result[k] = v
    return result


def _before_send(event: dict, hint: object) -> dict | None:
    """Gating por ambiente + scrubbing de PII/biometria antes de enviar ao Sentry."""
    if os.getenv("ENVIRONMENT", "").lower() != "production":
        return None

    # Scrub cabeçalhos da requisição (Authorization, cookies, etc.)
    request = event.get("request", {})
    if "headers" in request:
        request["headers"] = _scrub_dict(request["headers"])
    # Nunca enviar corpo da requisição (pode conter imagens/embeddings)
    if "data" in request:
        request["data"] = "[Filtered]"
    if request:
        event["request"] = request

    # Scrub contexto extra (ex.: query_params que incluam tokens)
    if "extra" in event:
        event["extra"] = _scrub_dict(event["extra"])

    return event


def capture_exception(exc: BaseException) -> None:
    """Captura exceção no Sentry se estiver inicializado."""
    if not _sentry_initialized:
        return
    try:
        import sentry_sdk
        sentry_sdk.capture_exception(exc)
    except Exception:
        pass


def init_sentry(dsn: str | None = None) -> None:
    """Inicializa Sentry se DSN estiver configurado."""
    global _sentry_initialized

    if _sentry_initialized:
        return

    sentry_dsn = dsn or os.getenv("SENTRY_DSN")

    if not sentry_dsn:
        logger.debug("Sentry não configurado (SENTRY_DSN não definido)")
        return

    try:
        import sentry_sdk
        from sentry_sdk.integrations.celery import CeleryIntegration
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.logging import LoggingIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

        sentry_sdk.init(
            dsn=sentry_dsn,
            integrations=[
                FastApiIntegration(),
                SqlalchemyIntegration(),
                CeleryIntegration(monitor_beat_tasks=True),
                LoggingIntegration(level=logging.ERROR, event_level=logging.ERROR),
            ],
            traces_sample_rate=0.1,
            send_default_pii=False,
            environment=os.getenv("ENVIRONMENT", "development"),
            release=os.getenv("APP_VERSION", "0.1.0"),
            before_send=_before_send,
        )

        _sentry_initialized = True
        logger.info("Sentry inicializado com sucesso")

    except ImportError:
        logger.warning("sentry-sdk não instalado. Instale com: pip install sentry-sdk[fastapi]")
    except Exception as e:
        logger.error("Erro ao inicializar Sentry: %s", e, exc_info=True)
