"""
Middleware para observabilidade: Request ID, logging de requisições HTTP e contexto.
"""
import logging
import time
import uuid
from contextvars import ContextVar
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from app.core.metrics import http_errors_total, http_request_duration_seconds, http_requests_total

logger = logging.getLogger(__name__)

# Context variables para armazenar informações da requisição atual
request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)
user_id_var: ContextVar[str | None] = ContextVar("user_id", default=None)
academy_id_var: ContextVar[str | None] = ContextVar("academy_id", default=None)


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Middleware que adiciona Request ID a todas as requisições."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Gerar ou usar Request ID do header
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        request_id_var.set(request_id)

        # Adicionar Request ID ao header da resposta
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware que loga todas as requisições HTTP e registra métricas."""

    def __init__(self, app: ASGIApp, log_successful: bool = False):
        super().__init__(app)
        self.log_successful = log_successful

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.time()
        method = request.method
        path = request.url.path
        query_params = dict(request.query_params)

        # Normalizar path para métricas (remover IDs dinâmicos)
        normalized_path = self._normalize_path(path)

        # Sanitizar dados sensíveis
        sanitized_params = self._sanitize_params(query_params)

        # Obter user_id e academy_id do contexto se disponível
        user_id = user_id_var.get()
        academy_id = academy_id_var.get()
        request_id = request_id_var.get()

        # Processar requisição
        error_type = None
        try:
            response = await call_next(request)
            status_code = response.status_code
            duration_seconds = time.time() - start_time
            duration_ms = duration_seconds * 1000

            # Registrar métricas Prometheus
            http_requests_total.labels(method=method, path=normalized_path, status_code=status_code).inc()
            http_request_duration_seconds.labels(method=method, path=normalized_path).observe(duration_seconds)

            # Registrar erro se status >= 400
            if status_code >= 400:
                error_type = f"http_{status_code}"
                http_errors_total.labels(
                    method=method, path=normalized_path, status_code=status_code, error_type=error_type
                ).inc()

            # Logar requisições com erro ou se log_successful estiver habilitado
            if status_code >= 400 or self.log_successful:
                logger.info(
                    "HTTP request",
                    extra={
                        "request_id": request_id,
                        "method": method,
                        "path": path,
                        "status_code": status_code,
                        "duration_ms": round(duration_ms, 2),
                        "user_id": user_id,
                        "academy_id": academy_id,
                        "query_params": sanitized_params if sanitized_params else None,
                    },
                )
            else:
                # Logar apenas em DEBUG para requisições bem-sucedidas
                logger.debug(
                    "HTTP request",
                    extra={
                        "request_id": request_id,
                        "method": method,
                        "path": path,
                        "status_code": status_code,
                        "duration_ms": round(duration_ms, 2),
                        "user_id": user_id,
                        "academy_id": academy_id,
                    },
                )

            return response

        except Exception as e:
            duration_seconds = time.time() - start_time
            duration_ms = duration_seconds * 1000
            error_type = type(e).__name__
            
            # Registrar métricas de erro
            http_errors_total.labels(
                method=method, path=normalized_path, status_code=500, error_type=error_type
            ).inc()
            http_request_duration_seconds.labels(method=method, path=normalized_path).observe(duration_seconds)
            
            logger.error(
                "HTTP request error",
                extra={
                    "request_id": request_id,
                    "method": method,
                    "path": path,
                    "duration_ms": round(duration_ms, 2),
                    "user_id": user_id,
                    "academy_id": academy_id,
                    "error": str(e),
                    "error_type": error_type,
                },
                exc_info=True,
            )
            raise

    def _normalize_path(self, path: str) -> str:
        """Normaliza path removendo IDs dinâmicos para métricas."""
        # Substituir UUIDs por {id}
        import re
        uuid_pattern = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
        normalized = re.sub(uuid_pattern, "{id}", path, flags=re.IGNORECASE)
        return normalized

    def _sanitize_params(self, params: dict) -> dict:
        """Remove parâmetros sensíveis dos logs."""
        sensitive_keys = {"password", "token", "secret", "authorization", "api_key"}
        return {k: "***" if k.lower() in sensitive_keys else v for k, v in params.items()}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Adiciona headers de segurança HTTP a todas as respostas."""

    _CACHEABLE_PREFIXES = ("/techniques", "/positions", "/lessons")

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"

        path = request.url.path
        if request.method == "GET" and any(path.startswith(p) for p in self._CACHEABLE_PREFIXES):
            response.headers["Cache-Control"] = "private, max-age=60"
        else:
            response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
            response.headers["Pragma"] = "no-cache"

        return response


def set_request_context(user_id: str | None = None, academy_id: str | None = None) -> None:
    """Define contexto da requisição atual para logging."""
    if user_id:
        user_id_var.set(str(user_id))
    if academy_id:
        academy_id_var.set(str(academy_id))


def get_request_id() -> str | None:
    """Retorna o Request ID da requisição atual."""
    return request_id_var.get()


class ContextFilter(logging.Filter):
    """Filter que adiciona contexto (request_id, user_id, academy_id) a todos os logs."""

    def filter(self, record: logging.LogRecord) -> bool:
        request_id = request_id_var.get()
        user_id = user_id_var.get()
        academy_id = academy_id_var.get()

        if request_id:
            record.request_id = request_id
        if user_id:
            record.user_id = user_id
        if academy_id:
            record.academy_id = academy_id

        return True
