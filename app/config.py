from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Configuração da aplicação (variáveis de ambiente)."""

    DATABASE_URL: str = "postgresql://jjb:jjb_secret@localhost:5432/jjb_db"
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
