import logging
from typing import List

from pydantic_settings import BaseSettings

_DEFAULT_JWT_SECRET = "altere-em-producao-use-um-secret-forte"


class Settings(BaseSettings):
    """Configuração da aplicação (variáveis de ambiente)."""

    DATABASE_URL: str = "postgresql://jjb:jjb_secret@localhost:5432/jjb_db"
    LOG_LEVEL: str = "INFO"

    # JWT (autenticação)
    JWT_SECRET: str = _DEFAULT_JWT_SECRET
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 dias

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    # Banco - pool
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 30

    # Seed automático no startup
    SEED_ON_STARTUP: bool = True

    # Rate limiting (login)
    LOGIN_RATE_LIMIT: str = "5/minute"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()

if settings.JWT_SECRET == _DEFAULT_JWT_SECRET:
    logging.getLogger(__name__).warning(
        "JWT_SECRET está com o valor padrão! Defina JWT_SECRET no .env para produção."
    )
