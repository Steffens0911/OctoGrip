"""Serviços CRUD para Position."""
import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import Position

logger = logging.getLogger(__name__)


def list_positions(db: Session, limit: int = 200) -> list[Position]:
    """Lista posições ordenadas por nome."""
    return db.query(Position).order_by(Position.name).limit(limit).all()


def get_position(db: Session, position_id: UUID) -> Position | None:
    """Retorna uma posição por ID."""
    return db.query(Position).filter(Position.id == position_id).first()


def create_position(
    db: Session,
    name: str,
    slug: str,
    description: str | None = None,
) -> Position:
    """Cria uma posição."""
    position = Position(
        name=name.strip(),
        slug=slug.strip(),
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
