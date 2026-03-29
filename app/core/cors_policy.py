"""
Política CORS (regex de origens) e eco explícito de headers nas respostas JSON.

O CORSMiddleware e o CorsFallbackMiddleware cobrem o fluxo ASGI normal; estes headers
reforçam respostas geradas pelos exception handlers e por rotas críticas (ex.: restore),
onde o browser às vezes não vê Access-Control-Allow-Origin (500 multipart, pipeline atípico).
"""
from __future__ import annotations

import os
import re
from starlette.requests import Request

_IS_PRODUCTION = os.getenv("ENVIRONMENT", "").lower() == "production"

_CORS_LOCALHOST_REGEX = (
    r"http://localhost(:\d+)?$"
    r"|http://127\.0\.0\.1(:\d+)?$"
    r"|http://\[::1\](:\d+)?$"
)
_CORS_LAN_DEV_REGEX = (
    r"|http://192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$"
    r"|http://10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$"
    r"|http://172\.(?:1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}(:\d+)?$"
)
_CORS_TRYCLOUDFLARE_DEV_REGEX = r"|https://[\w-]+\.trycloudflare\.com$"

CORS_ORIGIN_REGEX = (
    _CORS_LOCALHOST_REGEX + _CORS_LAN_DEV_REGEX + _CORS_TRYCLOUDFLARE_DEV_REGEX
    if not _IS_PRODUCTION
    else _CORS_LOCALHOST_REGEX
)
CORS_ORIGIN_REGEX_COMPILED = re.compile(CORS_ORIGIN_REGEX)


def is_allowed_cors_origin(origin: str) -> bool:
    return bool(CORS_ORIGIN_REGEX_COMPILED.fullmatch(origin))


def cors_echo_headers_for_request(request: Request) -> dict[str, str]:
    """Headers a acrescentar quando o Origin do pedido é permitido pelo regex."""
    origin = request.headers.get("origin")
    if not origin or not is_allowed_cors_origin(origin):
        return {}
    return {
        "Access-Control-Allow-Origin": origin,
        "Vary": "Origin",
    }


def merge_json_response_headers(request: Request, headers: dict[str, str] | None) -> dict[str, str] | None:
    """Junta headers existentes com CORS explícito (CORS não sobrescreve chaves já definidas)."""
    extra = cors_echo_headers_for_request(request)
    if not extra and not headers:
        return None
    merged: dict[str, str] = {}
    if headers:
        merged.update(headers)
    for k, v in extra.items():
        if k.lower() not in {x.lower() for x in merged}:
            merged[k] = v
    return merged or None
