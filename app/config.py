import logging
import os
from typing import List

from pydantic import field_validator
from pydantic_settings import BaseSettings

_DEFAULT_JWT_SECRET = "altere-em-producao-use-um-secret-forte"
_MIN_JWT_SECRET_LENGTH = 32


class Settings(BaseSettings):
    """Configuração da aplicação (variáveis de ambiente)."""

    DATABASE_URL: str = "postgresql://jjb:jjb_secret@localhost:5432/jjb_db"
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "text"  # text ou json
    
    # Observabilidade
    SENTRY_DSN: str | None = None
    ENABLE_METRICS: bool = True

    # JWT (autenticação)
    JWT_SECRET: str = _DEFAULT_JWT_SECRET
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 2  # 2 horas (reduzido de 7 dias)

    # CORS
    # Em desenvolvimento, o backend aceita localhost em qualquer porta via allow_origin_regex
    # configurado em app.main. Em produção, defina origens explícitas aqui (ex.: URLs do frontend).
    CORS_ORIGINS: List[str] = []

    # Banco - pool
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 30

    # Seed automático no startup
    SEED_ON_STARTUP: bool = True

    # Rate limiting (login)
    LOGIN_RATE_LIMIT: str = "5/minute"

    # Bónus de sequência de login (UTC): a cada N dias consecutivos no login, +X pts (points_adjustment).
    LOGIN_STREAK_BONUS_POINTS: int = 50
    LOGIN_STREAK_BONUS_INTERVAL_DAYS: int = 7

    # Download de backup SQL (admin); em testes use env mais folgada (ver conftest)
    BACKUP_DOWNLOAD_RATE_LIMIT: str = "3/hour"

    # Restauração de backup ZIP (admin): tamanho máximo do upload (slowapi não decora POST /restore)
    BACKUP_RESTORE_MAX_MB: int = 512
    BACKUP_RESTORE_RATE_LIMIT: str = "2/hour"  # legado / futuro; restore não usa este valor hoje
    # Restore: um único psql -f (preamble + database.sql); dumps grandes precisam de timeout alto
    BACKUP_PSQL_RESTORE_TIMEOUT_SEC: int = 7200
    BACKUP_PSQL_CONNECT_RETRIES: int = 5
    BACKUP_PSQL_CONNECT_RETRY_DELAY_SEC: float = 2.0

    # Account lockout
    ACCOUNT_LOCKOUT_ATTEMPTS: int = 5
    ACCOUNT_LOCKOUT_MINUTES: int = 15

    # Ambiente (development/production)
    ENVIRONMENT: str = "development"

    @field_validator("JWT_SECRET")
    @classmethod
    def validate_jwt_secret(cls, v: str) -> str:
        """Valida força do JWT_SECRET."""
        # Em produção, secret é obrigatório e deve ser forte
        is_production = os.getenv("ENVIRONMENT", "").lower() == "production"
        
        if v == _DEFAULT_JWT_SECRET:
            if is_production:
                raise ValueError(
                    "JWT_SECRET não pode usar o valor padrão em produção. "
                    "Defina uma secret forte via variável de ambiente."
                )
            logging.getLogger(__name__).warning(
                "JWT_SECRET está com o valor padrão! Defina JWT_SECRET no .env para produção."
            )
        
        # Validar força mínima (exceto se for o default em dev)
        if v != _DEFAULT_JWT_SECRET and len(v) < _MIN_JWT_SECRET_LENGTH:
            raise ValueError(
                f"JWT_SECRET deve ter pelo menos {_MIN_JWT_SECRET_LENGTH} caracteres. "
                f"Atual: {len(v)} caracteres."
            )
        
        return v

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def cors_origins_coerce_empty(cls, v):
        """Docker/compose pode passar CORS_ORIGINS= vazio — JSON inválido sem isso."""
        if v is None or (isinstance(v, str) and not v.strip()):
            return []
        return v

    @field_validator("CORS_ORIGINS")
    @classmethod
    def validate_cors_origins(cls, v: List[str]) -> List[str]:
        """Valida CORS; remove '*' (quebra Flutter Web + Authorization: browser exige origem explícita)."""
        is_production = os.getenv("ENVIRONMENT", "").lower() == "production"

        if is_production and "*" in v:
            raise ValueError(
                "CORS_ORIGINS não pode conter '*' em produção. "
                "Defina origens específicas via variável de ambiente."
            )

        return [o for o in v if o and str(o).strip() != "*"]

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()

if settings.JWT_SECRET == _DEFAULT_JWT_SECRET:
    logging.getLogger(__name__).warning(
        "JWT_SECRET está com o valor padrão! Defina JWT_SECRET no .env para produção."
    )
