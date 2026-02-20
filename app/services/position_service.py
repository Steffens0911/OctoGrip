"""Serviços CRUD para Position."""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.slug import ensure_unique_slug, make_slug
from app.models import Position

logger = logging.getLogger(__name__)


async def list_positions(db: AsyncSession, academy_id: UUID | None = None, limit: int = 200) -> list[Position]:
    """Lista posições ordenadas por nome. Se academy_id informado, filtra por academia."""
    stmt = select(Position)
    if academy_id is not None:
        stmt = stmt.where(Position.academy_id == academy_id)
    return (await db.execute(stmt.order_by(Position.name).limit(limit))).scalars().all()


async def get_position(db: AsyncSession, position_id: UUID) -> Position | None:
    """Retorna uma posição por ID."""
    return (await db.execute(select(Position).where(Position.id == position_id))).scalar_one_or_none()


async def create_position(
    db: AsyncSession,
    academy_id: UUID,
    name: str,
    slug: str | None = None,
    description: str | None = None,
) -> Position:
    """Cria uma posição na academia. Slug gerado automaticamente a partir do nome se omitido."""
    if not slug or not str(slug).strip():
        base = make_slug(name, fallback="posicao")
        slug = await ensure_unique_slug(db, Position, "slug", base, academy_id=academy_id)
    else:
        slug = slug.strip()
    position = Position(
        academy_id=academy_id,
        name=name.strip(),
        slug=slug,
        description=description.strip() if description else None,
    )
    db.add(position)
    await db.commit()
    await db.refresh(position)
    logger.info("create_position", extra={"position_id": str(position.id), "position_name": position.name})
    return position


async def update_position(
    db: AsyncSession,
    position_id: UUID,
    name: str | None = None,
    slug: str | None = None,
    description: str | None = None,
) -> Position | None:
    """Atualiza uma posição. Retorna None se não existir."""
    position = await get_position(db, position_id)
    if not position:
        return None
    if name is not None:
        position.name = name.strip()
    if slug is not None:
        position.slug = slug.strip()
    if description is not None:
        position.description = description.strip() if description else None
    await db.commit()
    await db.refresh(position)
    logger.info("update_position", extra={"position_id": str(position_id)})
    return position


async def delete_position(db: AsyncSession, position_id: UUID) -> bool:
    """Remove uma posição. Retorna True se removeu, False se não existir."""
    position = await get_position(db, position_id)
    if not position:
        return False
    await db.delete(position)
    await db.commit()
    logger.info("delete_position", extra={"position_id": str(position_id)})
    return True
