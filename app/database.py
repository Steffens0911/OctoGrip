from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import sessionmaker, declarative_base

from app.config import settings

_async_url = settings.DATABASE_URL.replace(
    "postgresql://", "postgresql+asyncpg://", 1
)

async_engine = create_async_engine(
    _async_url,
    pool_pre_ping=True,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
    echo=False,
)

AsyncSessionLocal = async_sessionmaker(
    async_engine, class_=AsyncSession, expire_on_commit=False
)

# Sync engine kept for migrations (run_migrations.py) and seed
sync_engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=5,
    echo=False,
)

SyncSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=sync_engine)

Base = declarative_base()


async def get_db():
    """Dependency: sessão async do banco para injeção em routes."""
    async with AsyncSessionLocal() as session:
        yield session


# Alias mantido para compatibilidade com seed e migrations
engine = sync_engine
SessionLocal = SyncSessionLocal
