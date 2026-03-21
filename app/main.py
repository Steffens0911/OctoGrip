import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from slowapi import _rate_limit_exceeded_handler
from starlette.staticfiles import StaticFiles
from pathlib import Path
from slowapi.errors import RateLimitExceeded

from app.config import settings
from app.core.error_tracking import init_sentry
from app.core.exceptions import AppError, AuthenticationError
from app.core.logging_config import setup_logging
from app.core.middleware import ContextFilter, RequestIDMiddleware, RequestLoggingMiddleware, SecurityHeadersMiddleware, get_request_id
from app.core.metrics import http_errors_total
from app.core.rate_limit import limiter
from app.database import engine
from app.models import Base  # noqa: F401 — registra models para migrações
from app.routes.router import api_router
from app.run_migrations import run_migrations
from app.scripts.seed import run_seed

logger = logging.getLogger(__name__)

_IS_PRODUCTION = os.getenv("ENVIRONMENT", "").lower() == "production"


def register_exception_handlers(application: FastAPI) -> None:
    """Mapeia exceções de domínio e erros não tratados para respostas HTTP (com CORS)."""

    @application.exception_handler(AppError)
    def app_error_handler(request: Request, exc: AppError):
        request_id = get_request_id()
        error_type = type(exc).__name__

        http_errors_total.labels(
            method=request.method,
            path=request.url.path,
            status_code=exc.status_code,
            error_type=error_type,
        ).inc()

        logger.warning(
            "AppError tratada",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": exc.status_code,
                "error_type": error_type,
                "error_message": exc.message,
            },
        )

        headers = {}
        if isinstance(exc, AuthenticationError):
            headers["WWW-Authenticate"] = "Bearer"

        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.message},
            headers=headers or None,
        )

    @application.exception_handler(Exception)
    def unhandled_exception_handler(request: Request, exc: Exception):
        request_id = get_request_id()
        error_type = type(exc).__name__

        # Registrar métrica de erro
        http_errors_total.labels(
            method=request.method,
            path=request.url.path,
            status_code=500,
            error_type=error_type,
        ).inc()
        
        # Logar com contexto completo
        logger.exception(
            "Exceção não tratada: %s",
            exc,
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "query_params": dict(request.query_params) if request.query_params else None,
                "error_type": error_type,
                "error_message": str(exc),
            },
        )
        
        # Em produção, não expor detalhes do erro para evitar vazamento de informações
        if _IS_PRODUCTION:
            detail = "Erro interno do servidor."
        else:
            # Em desenvolvimento, mostrar detalhes para facilitar debug
            detail = str(exc) or "Erro interno do servidor."
        
        return JSONResponse(
            status_code=500,
            content={"detail": detail},
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Cria tabelas a partir dos models (se não existirem), aplica migrações e (opcionalmente) roda seed ao subir a API."""
    setup_logging(level=settings.LOG_LEVEL, format_type=settings.LOG_FORMAT)

    # Inicializar Sentry se configurado
    init_sentry(settings.SENTRY_DSN)

    # Garante que tabelas base (users, lessons, techniques, etc.) existam antes das migrações
    Base.metadata.create_all(bind=engine)
    run_migrations(engine)
    if settings.SEED_ON_STARTUP:
        run_seed()
    else:
        logger.info("Seed desabilitado (SEED_ON_STARTUP=false).")
    yield


app = FastAPI(
    title="JJB API",
    description="API do MVP SaaS de ensino de jiu-jitsu para iniciantes",
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if not _IS_PRODUCTION else None,
    redoc_url="/redoc" if not _IS_PRODUCTION else None,
    openapi_url="/openapi.json" if not _IS_PRODUCTION else None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Middleware de Request ID (deve ser o primeiro)
app.add_middleware(RequestIDMiddleware)

# Middleware de headers de segurança
app.add_middleware(SecurityHeadersMiddleware)

# Middleware de logging de requisições
app.add_middleware(RequestLoggingMiddleware, log_successful=False)

# CORS: allow_headers=["*"] com allow_credentials=False é suportado pelo Starlette e espelha no preflight
# os headers pedidos pelo browser (Authorization, X-Impersonate-User, extensões, etc.). Evita 400
# "Disallowed CORS headers" que bloqueava Flutter Web (CRUD troféus, /auth/me, etc.) mesmo com lista explícita.
app.add_middleware(
    CORSMiddleware,
    # Em produção, use CORS_ORIGINS para listar domínios permitidos (ex.: frontend em produção).
    allow_origins=settings.CORS_ORIGINS,
    # Flutter Web: localhost com porta dinâmica, 127.0.0.1 e ::1 (IPv6).
    allow_origin_regex=(
        r"http://localhost(:\d+)?$"
        r"|http://127\.0\.0\.1(:\d+)?$"
        r"|http://\[::1\](:\d+)?$"
    ),
    # Usamos autenticação via header Authorization: Bearer, então não precisamos de credenciais de cookie.
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
    allow_headers=["*"],
)

register_exception_handlers(app)
app.include_router(api_router)

# Arquivos estáticos (ex.: logos/brasões de academias)
_BASE_DIR = Path(__file__).resolve().parent.parent
_MEDIA_ROOT = _BASE_DIR / "app_media"
_MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=str(_MEDIA_ROOT)), name="media")


@app.get("/", response_class=HTMLResponse, include_in_schema=False)
def home():
    """Página inicial com links para documentação e painel de administração."""
    return """<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>JJB API</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; max-width: 480px; margin: 48px auto; padding: 0 24px; text-align: center; }
    h1 { font-size: 1.5rem; color: #333; }
    p { color: #666; margin-bottom: 24px; }
    a { display: inline-block; padding: 14px 24px; margin: 8px; background: #58CC02; color: #fff; text-decoration: none; border-radius: 8px; font-weight: 500; }
    a:hover { background: #46A302; }
    a.secondary { background: #1a1a2e; }
    a.secondary:hover { background: #252540; }
  </style>
</head>
<body>
  <h1>JJB API</h1>
  <p>API do MVP de ensino de jiu-jitsu para iniciantes.</p>
  <a href="/admin">Painel de administração</a>
  <a href="/docs" class="secondary">Documentação da API</a>
</body>
</html>"""
