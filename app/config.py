from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Configuração da aplicação (variáveis de ambiente)."""

    DATABASE_URL: str = "postgresql://jjb:jjb_secret@localhost:5432/jjb_db"
    LOG_LEVEL: str = "INFO"
    # JWT (autenticação)
    JWT_SECRET: str = "altere-em-producao-use-um-secret-forte"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 dias

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
