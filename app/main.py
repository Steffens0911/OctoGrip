from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.core.exceptions import AppError
from app.core.logging_config import setup_logging
from app.database import engine
from app.models import Base  # importa todos os models via __init__ (registro para create_all)
from app.routes.router import api_router


def register_exception_handlers(app: FastAPI) -> None:
    """Mapeia exceções de domínio para respostas HTTP."""

    @app.exception_handler(AppError)
    def app_error_handler(request, exc: AppError):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.message},
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Cria tabelas ao subir a API (MVP; em produção use migrations)."""
    setup_logging(level=settings.LOG_LEVEL)
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="JJB API",
    description="API do MVP SaaS de ensino de jiu-jitsu para iniciantes",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)
app.include_router(api_router)
