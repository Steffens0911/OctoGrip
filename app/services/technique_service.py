"""Serviços CRUD para Technique."""
import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.slug import ensure_unique_slug, make_slug
from app.models import Position, Technique

logger = logging.getLogger(__name__)


def list_techniques(db: Session, academy_id: UUID | None = None, limit: int = 200) -> list[Technique]:
    """Lista técnicas ordenadas por nome. Se academy_id informado, filtra por academia."""
    q = db.query(Technique)
    if academy_id is not None:
        q = q.filter(Technique.academy_id == academy_id)
    return q.order_by(Technique.name).limit(limit).all()


def get_technique(db: Session, technique_id: UUID) -> Technique | None:
    """Retorna uma técnica por ID."""
    return db.query(Technique).filter(Technique.id == technique_id).first()


def create_technique(
    db: Session,
    academy_id: UUID,
    name: str,
    from_position_id: UUID,
    to_position_id: UUID,
    slug: str | None = None,
    description: str | None = None,
    video_url: str | None = None,
    base_points: int | None = None,
) -> Technique:
    """Cria uma técnica na academia. from_position e to_position devem pertencer à mesma academia."""
    from_pos = db.query(Position).filter(Position.id == from_position_id).first()
    to_pos = db.query(Position).filter(Position.id == to_position_id).first()
    if not from_pos or from_pos.academy_id != academy_id:
        raise ValueError("from_position_id deve ser uma posição desta academia.")
    if not to_pos or to_pos.academy_id != academy_id:
        raise ValueError("to_position_id deve ser uma posição desta academia.")
    if not slug or not str(slug).strip():
        base = make_slug(name, fallback="tecnica")
        slug = ensure_unique_slug(db, Technique, "slug", base, academy_id=academy_id)
    else:
        slug = slug.strip()
    technique = Technique(
        academy_id=academy_id,
        name=name.strip(),
        slug=slug,
        from_position_id=from_position_id,
        to_position_id=to_position_id,
        description=description.strip() if description else None,
        video_url=video_url.strip() if video_url and video_url.strip() else None,
        base_points=base_points,
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
    video_url: str | None = None,
    base_points: int | None = None,
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
    if video_url is not None:
        technique.video_url = video_url.strip() if video_url and video_url.strip() else None
    if base_points is not None:
        technique.base_points = base_points
    if from_position_id is not None:
        from_pos = db.query(Position).filter(Position.id == from_position_id).first()
        if not from_pos or from_pos.academy_id != technique.academy_id:
            raise ValueError("from_position_id deve ser uma posição desta academia.")
        technique.from_position_id = from_position_id
    if to_position_id is not None:
        to_pos = db.query(Position).filter(Position.id == to_position_id).first()
        if not to_pos or to_pos.academy_id != technique.academy_id:
            raise ValueError("to_position_id deve ser uma posição desta academia.")
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
