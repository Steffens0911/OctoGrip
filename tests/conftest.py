"""
Fixtures compartilhadas para os testes da API.

Usa PostgreSQL real (banco jjb_db_test).
Todos os dados usam UUIDs únicos, dispensando limpeza entre testes.
"""
import os
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql://jjb:jjb_secret@localhost:5432/jjb_db_test",
)
os.environ["SEED_ON_STARTUP"] = "false"

from app.config import settings  # noqa: E402
from app.core.security import create_access_token, hash_password  # noqa: E402
from app.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402

_async_url = settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

_engine = create_async_engine(_async_url, echo=False, pool_size=5, max_overflow=10)
_session_factory = async_sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture(scope="session", autouse=True)
async def _create_tables():
    async with _engine.begin() as conn:
        await conn.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
        await conn.execute(text("CREATE SCHEMA public"))
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with _engine.begin() as conn:
        await conn.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
        await conn.execute(text("CREATE SCHEMA public"))
    await _engine.dispose()


@pytest.fixture
async def db():
    async with _session_factory() as session:
        yield session


@pytest.fixture
async def client():
    async def _override_get_db():
        async with _session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = _override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Entidades reutilizáveis
# ---------------------------------------------------------------------------

@pytest.fixture
async def admin_user(db: AsyncSession):
    from app.models import User

    user = User(
        email=f"admin-{uuid4().hex[:8]}@test.com",
        name="Admin Teste",
        role="administrador",
        password_hash=hash_password("admin123"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
def admin_token(admin_user) -> str:
    return create_access_token(admin_user.id)


@pytest.fixture
def admin_headers(admin_token) -> dict:
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
async def academy(db: AsyncSession):
    from app.models import Academy

    a = Academy(name=f"Academia {uuid4().hex[:6]}", slug=f"acad-{uuid4().hex[:6]}")
    db.add(a)
    await db.commit()
    await db.refresh(a)
    return a


@pytest.fixture
async def professor_user(db: AsyncSession, academy):
    from app.models import User

    user = User(
        email=f"prof-{uuid4().hex[:8]}@test.com",
        name="Professor Teste",
        role="professor",
        graduation="black",
        academy_id=academy.id,
        password_hash=hash_password("prof1234"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
def professor_token(professor_user) -> str:
    return create_access_token(professor_user.id)


@pytest.fixture
def professor_headers(professor_token) -> dict:
    return {"Authorization": f"Bearer {professor_token}"}


@pytest.fixture
async def aluno_user(db: AsyncSession, academy):
    from app.models import User

    user = User(
        email=f"aluno-{uuid4().hex[:8]}@test.com",
        name="Aluno Teste",
        role="aluno",
        graduation="white",
        academy_id=academy.id,
        password_hash=hash_password("aluno123"),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


@pytest.fixture
def aluno_token(aluno_user) -> str:
    return create_access_token(aluno_user.id)


@pytest.fixture
def aluno_headers(aluno_token) -> dict:
    return {"Authorization": f"Bearer {aluno_token}"}


@pytest.fixture
async def technique(db: AsyncSession, academy):
    from app.models import Technique

    t = Technique(
        academy_id=academy.id,
        name=f"Raspagem {uuid4().hex[:4]}",
        slug=f"raspagem-{uuid4().hex[:6]}",
        base_points=10,
    )
    db.add(t)
    await db.commit()
    await db.refresh(t)
    return t
