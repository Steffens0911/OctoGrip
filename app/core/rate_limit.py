"""Rate-limiter global (slowapi).

As contagens ficam no Redis para valer entre os workers do uvicorn; se o Redis cair, o slowapi
segue com contagem em memória até ele voltar. A chave é o IP real do cliente (ver client_ip).
"""

from slowapi import Limiter

from app.config import settings
from app.core.client_ip import get_client_ip

limiter = Limiter(
    key_func=get_client_ip,
    default_limits=["60/minute"],
    storage_uri=settings.rate_limit_storage_uri,
    # Timeout curto: a checagem do slowapi é síncrona e não pode travar o event loop.
    storage_options={"socket_connect_timeout": 0.5, "socket_timeout": 0.5},
    in_memory_fallback_enabled=True,
    key_prefix="ratelimit",
)
