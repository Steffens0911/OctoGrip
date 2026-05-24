from __future__ import annotations

import logging

from sqlalchemy import text

from app.config import settings
from app.core.logging_config import setup_logging
from app.database import engine
from app.models import Base  # noqa: F401
from app.run_migrations import run_migrations
from app.scripts.seed import run_seed

logger = logging.getLogger(__name__)


def ensure_public_schema_sync() -> None:
    """Garante schema public consistente antes de criar tabelas/migrar."""
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS public"))
        conn.execute(text("ALTER SCHEMA public OWNER TO CURRENT_USER"))
        conn.execute(text("GRANT ALL ON SCHEMA public TO CURRENT_USER"))
        conn.execute(text("GRANT USAGE ON SCHEMA public TO PUBLIC"))
        conn.execute(
            text(
                "DO $$ BEGIN EXECUTE format('ALTER DATABASE %I SET search_path TO public', current_database()); END $$;"
            )
        )


def run_bootstrap() -> None:
    """
    Executa bootstrap pesado UMA vez antes do multi-worker da API:
    - create schema
    - create_all
    - run migrations
    - optional seed
    """
    setup_logging(level=settings.LOG_LEVEL, format_type=settings.LOG_FORMAT)
    ensure_public_schema_sync()
    Base.metadata.create_all(bind=engine)
    run_migrations(engine)
    if settings.SEED_ON_STARTUP:
        run_seed()
    else:
        logger.info("Seed desabilitado (SEED_ON_STARTUP=false).")


if __name__ == "__main__":
    run_bootstrap()
