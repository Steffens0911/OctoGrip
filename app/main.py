import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.config import settings
from app.core.exceptions import AppError
from app.core.logging_config import setup_logging
from app.core.rate_limit import limiter
from app.database import engine
from app.models import Base  # noqa: F401 — registra models para migrações
from app.routes.router import api_router
from app.run_migrations import run_migrations
from app.scripts.seed import run_seed

logger = logging.getLogger(__name__)


def register_exception_handlers(application: FastAPI) -> None:
    """Mapeia exceções de domínio e erros não tratados para respostas HTTP (com CORS)."""

    @application.exception_handler(AppError)
    def app_error_handler(request: Request, exc: AppError):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.message},
        )

    @application.exception_handler(Exception)
    def unhandled_exception_handler(request: Request, exc: Exception):
        logger.exception("Exceção não tratada: %s", exc)
        return JSONResponse(
            status_code=500,
            content={"detail": str(exc) or "Erro interno do servidor."},
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Aplica migrações e (opcionalmente) roda seed ao subir a API."""
    setup_logging(level=settings.LOG_LEVEL)
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
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

register_exception_handlers(app)
app.include_router(api_router)


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
