"""Serviços CRUD para Position."""
import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.slug import ensure_unique_slug, make_slug
from app.models import Position

logger = logging.getLogger(__name__)


def list_positions(db: Session, academy_id: UUID | None = None, limit: int = 200) -> list[Position]:
    """Lista posições ordenadas por nome. Se academy_id informado, filtra por academia."""
    q = db.query(Position)
    if academy_id is not None:
        q = q.filter(Position.academy_id == academy_id)
    return q.order_by(Position.name).limit(limit).all()


def get_position(db: Session, position_id: UUID) -> Position | None:
    """Retorna uma posição por ID."""
    return db.query(Position).filter(Position.id == position_id).first()


def create_position(
    db: Session,
    academy_id: UUID,
    name: str,
    slug: str | None = None,
    description: str | None = None,
) -> Position:
    """Cria uma posição na academia. Slug gerado automaticamente a partir do nome se omitido."""
    if not slug or not str(slug).strip():
        base = make_slug(name, fallback="posicao")
        slug = ensure_unique_slug(db, Position, "slug", base, academy_id=academy_id)
    else:
        slug = slug.strip()
    position = Position(
        academy_id=academy_id,
        name=name.strip(),
        slug=slug,
        description=description.strip() if description else None,
    )
    db.add(position)
    db.commit()
    db.refresh(position)
    logger.info("create_position", extra={"position_id": str(position.id), "position_name": position.name})
    return position


def update_position(
    db: Session,
    position_id: UUID,
    name: str | None = None,
    slug: str | None = None,
    description: str | None = None,
) -> Position | None:
    """Atualiza uma posição. Retorna None se não existir."""
    position = get_position(db, position_id)
    if not position:
        return None
    if name is not None:
        position.name = name.strip()
    if slug is not None:
        position.slug = slug.strip()
    if description is not None:
        position.description = description.strip() if description else None
    db.commit()
    db.refresh(position)
    logger.info("update_position", extra={"position_id": str(position_id)})
    return position


def delete_position(db: Session, position_id: UUID) -> bool:
    """Remove uma posição. Retorna True se removeu, False se não existir."""
    position = get_position(db, position_id)
    if not position:
        return False
    db.delete(position)
    db.commit()
    logger.info("delete_position", extra={"position_id": str(position_id)})
    return True
