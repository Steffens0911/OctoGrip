"""Serviços CRUD para Professor (seção professor)."""
import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import Professor

logger = logging.getLogger(__name__)


def list_professors(
    db: Session,
    academy_id: UUID | None = None,
    limit: int = 200,
) -> list[Professor]:
    """Lista professores, opcionalmente filtrados por academia."""
    q = db.query(Professor).order_by(Professor.name)
    if academy_id is not None:
        q = q.filter(Professor.academy_id == academy_id)
    return q.limit(limit).all()


def get_professor(db: Session, professor_id: UUID) -> Professor | None:
    """Retorna um professor por ID."""
    return db.query(Professor).filter(Professor.id == professor_id).first()


def create_professor(
    db: Session,
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
    db.commit()
    db.refresh(professor)
    logger.info(
        "create_professor",
        extra={"professor_id": str(professor.id), "email": professor.email},
    )
    return professor


def update_professor(
    db: Session,
    professor_id: UUID,
    name: str | None = None,
    email: str | None = None,
    academy_id: UUID | None = None,
) -> Professor | None:
    """Atualiza um professor."""
    professor = get_professor(db, professor_id)
    if not professor:
        return None
    if name is not None:
        professor.name = name.strip()
    if email is not None:
        professor.email = email.strip()
    if academy_id is not None:
        professor.academy_id = academy_id
    db.commit()
    db.refresh(professor)
    logger.info("update_professor", extra={"professor_id": str(professor_id)})
    return professor


def delete_professor(db: Session, professor_id: UUID) -> bool:
    """Remove um professor. Retorna True se removeu."""
    professor = get_professor(db, professor_id)
    if not professor:
        return False
    db.delete(professor)
    db.commit()
    logger.info("delete_professor", extra={"professor_id": str(professor_id)})
    return True
