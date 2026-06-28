import logging
import os
from zoneinfo import ZoneInfo

from pydantic import field_validator
from pydantic_settings import BaseSettings

_DEFAULT_JWT_SECRET = "altere-em-producao-use-um-secret-forte"
_MIN_JWT_SECRET_LENGTH = 32


class Settings(BaseSettings):
    """Configuração da aplicação (variáveis de ambiente)."""

    DATABASE_URL: str = "postgresql://jjb:dev_local_only@localhost:5432/jjb_db"
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "text"  # text ou json

    # Observabilidade
    SENTRY_DSN: str | None = None
    ENABLE_METRICS: bool = True

    # JWT (autenticação)
    JWT_SECRET: str = _DEFAULT_JWT_SECRET
    JWT_ALGORITHM: str = "HS256"
    # Sessão longa no app (telefone de um só utilizador). Em ambientes partilhados ou
    # requisitos mais rígidos, defina JWT_EXPIRE_MINUTES menor (ex.: 120) via env.
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 dias

    # CORS
    # Em desenvolvimento, o backend aceita localhost em qualquer porta via allow_origin_regex
    # configurado em app.main. Em produção, defina origens explícitas aqui (ex.: URLs do frontend).
    CORS_ORIGINS: list[str] = []

    # Banco - pool (POR WORKER uvicorn: 4 workers × (12+6) = 72 conexões máx.,
    # folga p/ Celery e psql dentro de max_connections=100 do Postgres)
    DB_POOL_SIZE: int = 12
    DB_MAX_OVERFLOW: int = 6

    # Seed automático no startup
    SEED_ON_STARTUP: bool = False

    # Rate limiting (login)
    LOGIN_RATE_LIMIT: str = "10/minute"

    # Fuso para "hoje", sequência de login, semana ISO de turmas, relatórios por dia, etc.
    APP_TIMEZONE: str = "America/Sao_Paulo"

    # Bónus de sequência de login: a cada N dias consecutivos (calendário no fuso APP_TIMEZONE), +X pts.
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

    # Chamada QR — assina tokens de presença (HMAC-SHA256). Em produção, use valor forte via env.
    QR_SECRET: str = "dev-local-only-qr-secret"

    # Ambiente (development/production)
    ENVIRONMENT: str = "development"

    # Firebase Cloud Messaging (notificações push; opcional)
    FIREBASE_PROJECT_ID: str | None = None
    FIREBASE_SERVICE_ACCOUNT_PATH: str | None = None
    # Desabilite em dev para não disparar push reais usando o Firebase de produção.
    PUSH_NOTIFICATIONS_ENABLED: bool = False

    # Recuperação de senha por e-mail (Resend)
    RESEND_API_KEY: str | None = None
    RESEND_FROM_EMAIL: str = "noreply@octogrip.app"
    PASSWORD_RESET_EXPIRE_MINUTES: int = 60
    # URL base do app (Flutter Web ou landing page) onde o link de reset aponta
    APP_BASE_URL: str = "http://localhost:8000"

    # Reconhecimento facial (fila assíncrona)
    REDIS_URL: str = "redis://localhost:6379/0"
    FACE_JOBS_DIR: str = "/tmp/face_jobs"
    FACE_MAX_IMAGE_SIDE: int = 1280
    # Pré-aquece o modelo facial no startup dos workers da API (elimina o cold
    # start de ~16s na primeira chamada do quiosque). Custo: ~830MB de RAM por
    # worker, ocupados desde o boot. Desligue em ambientes com pouca memória.
    FACE_WARMUP_ON_STARTUP: bool = True

    # LGPD / Privacidade
    # Versão vigente de cada documento legal. Quando o texto muda de forma relevante,
    # incremente a versão (ex.: nova data): consentimentos com versão anterior passam a
    # constar como "desatualizados" e o app deve pedir novo aceite.
    LEGAL_TERMS_VERSION: str = "2026-06-13"
    LEGAL_PRIVACY_VERSION: str = "2026-06-13"
    LEGAL_BIOMETRIC_VERSION: str = "2026-06-13"
    # Contato do Encarregado de Dados (DPO) exibido nos documentos e no canal de direitos do titular.
    DPO_CONTACT_EMAIL: str = "privacidade@octogrip.com.br"

    @field_validator("QR_SECRET")
    @classmethod
    def validate_qr_secret(cls, v: str) -> str:
        """Valida força do QR_SECRET em produção."""
        is_production = os.getenv("ENVIRONMENT", "").lower() == "production"
        if is_production and (not v or len(v) < _MIN_JWT_SECRET_LENGTH or "dev" in v.lower()):
            raise ValueError(
                "QR_SECRET não pode usar o valor padrão em produção. Defina um secret forte via variável de ambiente."
            )
        return v

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
                f"JWT_SECRET deve ter pelo menos {_MIN_JWT_SECRET_LENGTH} caracteres. Atual: {len(v)} caracteres."
            )

        return v

    @field_validator("APP_TIMEZONE")
    @classmethod
    def validate_app_timezone(cls, v: str) -> str:
        key = (v or "").strip()
        if not key:
            raise ValueError("APP_TIMEZONE não pode ser vazio.")
        try:
            ZoneInfo(key)
        except Exception as e:
            raise ValueError(f"APP_TIMEZONE inválido: {key!r}") from e
        return key

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def cors_origins_coerce_empty(cls, v):
        """Docker/compose pode passar CORS_ORIGINS= vazio — JSON inválido sem isso."""
        if v is None or (isinstance(v, str) and not v.strip()):
            return []
        return v

    @field_validator("CORS_ORIGINS")
    @classmethod
    def validate_cors_origins(cls, v: list[str]) -> list[str]:
        """Valida CORS; remove '*' (quebra Flutter Web + Authorization: browser exige origem explícita)."""
        is_production = os.getenv("ENVIRONMENT", "").lower() == "production"

        if is_production and "*" in v:
            raise ValueError(
                "CORS_ORIGINS não pode conter '*' em produção. Defina origens específicas via variável de ambiente."
            )

        return [o for o in v if o and str(o).strip() != "*"]

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()

if settings.JWT_SECRET == _DEFAULT_JWT_SECRET:
    logging.getLogger(__name__).warning("JWT_SECRET está com o valor padrão! Defina JWT_SECRET no .env para produção.")
