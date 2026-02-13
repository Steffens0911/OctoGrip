"""Serviços CRUD para Technique."""
import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import Technique

logger = logging.getLogger(__name__)


def list_techniques(db: Session, limit: int = 200) -> list[Technique]:
    """Lista técnicas ordenadas por nome."""
    return db.query(Technique).order_by(Technique.name).limit(limit).all()


def get_technique(db: Session, technique_id: UUID) -> Technique | None:
    """Retorna uma técnica por ID."""
    return db.query(Technique).filter(Technique.id == technique_id).first()


def create_technique(
    db: Session,
    name: str,
    slug: str,
    from_position_id: UUID,
    to_position_id: UUID,
    description: str | None = None,
) -> Technique:
    """Cria uma técnica."""
    technique = Technique(
        name=name.strip(),
        slug=slug.strip(),
        from_position_id=from_position_id,
        to_position_id=to_position_id,
        description=description.strip() if description else None,
    )
    db.add(technique)
    db.commit()
    db.refresh(technique)
    logger.info("create_technique", extra={"technique_id": str(technique.id), "technique_name": technique.name})
    return technique


def update_technique(
    db: Session,
    technique_id: UUID,
    name: str | None = None,
    slug: str | None = None,
    description: str | None = None,
    from_position_id: UUID | None = None,
    to_position_id: UUID | None = None,
) -> Technique | None:
    """Atualiza uma técnica. Retorna None se não existir."""
    technique = get_technique(db, technique_id)
    if not technique:
        return None
    if name is not None:
        technique.name = name.strip()
    if slug is not None:
        technique.slug = slug.strip()
    if description is not None:
        technique.description = description.strip() if description else None
    if from_position_id is not None:
        technique.from_position_id = from_position_id
    if to_position_id is not None:
        technique.to_position_id = to_position_id
    db.commit()
    db.refresh(technique)
    logger.info("update_technique", extra={"technique_id": str(technique_id)})
    return technique


def delete_technique(db: Session, technique_id: UUID) -> bool:
    """Remove uma técnica. Retorna True se removeu, False se não existir."""
    technique = get_technique(db, technique_id)
    if not technique:
        return False
    db.delete(technique)
    db.commit()
    logger.info("delete_technique", extra={"technique_id": str(technique_id)})
    return True
