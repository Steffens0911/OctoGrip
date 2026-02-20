"""Serviços CRUD para Professor (seção professor)."""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Professor

logger = logging.getLogger(__name__)


async def list_professors(
    db: AsyncSession,
    academy_id: UUID | None = None,
    limit: int = 200,
) -> list[Professor]:
    """Lista professores, opcionalmente filtrados por academia."""
    stmt = select(Professor).order_by(Professor.name)
    if academy_id is not None:
        stmt = stmt.where(Professor.academy_id == academy_id)
    return (await db.execute(stmt.limit(limit))).scalars().all()


async def get_professor(db: AsyncSession, professor_id: UUID) -> Professor | None:
    """Retorna um professor por ID."""
    return (await db.execute(select(Professor).where(Professor.id == professor_id))).scalar_one_or_none()


async def create_professor(
    db: AsyncSession,
    name: str,
    email: str,
    academy_id: UUID | None = None,
) -> Professor:
    """Cria um professor."""
    professor = Professor(
        name=name.strip(),
        email=email.strip(),
        academy_id=academy_id,
    )
    db.add(professor)
    await db.commit()
    await db.refresh(professor)
    logger.info(
        "create_professor",
        extra={"professor_id": str(professor.id), "email": professor.email},
    )
    return professor


async def update_professor(
    db: AsyncSession,
    professor_id: UUID,
    name: str | None = None,
    email: str | None = None,
    academy_id: UUID | None = None,
) -> Professor | None:
    """Atualiza um professor."""
    professor = await get_professor(db, professor_id)
    if not professor:
        return None
    if name is not None:
        professor.name = name.strip()
    if email is not None:
        professor.email = email.strip()
    if academy_id is not None:
        professor.academy_id = academy_id
    await db.commit()
    await db.refresh(professor)
    logger.info("update_professor", extra={"professor_id": str(professor_id)})
    return professor


async def delete_professor(db: AsyncSession, professor_id: UUID) -> bool:
    """Remove um professor. Retorna True se removeu."""
    professor = await get_professor(db, professor_id)
    if not professor:
        return False
    await db.delete(professor)
    await db.commit()
    logger.info("delete_professor", extra={"professor_id": str(professor_id)})
    return True
