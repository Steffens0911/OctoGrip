"""Serviços CRUD para User (painel desenvolvedores)."""
import logging
from uuid import UUID

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models import (
    LessonProgress,
    MissionUsage,
    TechniqueExecution,
    TrainingFeedback,
    User,
)
from app.core.security import hash_password

logger = logging.getLogger(__name__)


def list_users(
    db: Session,
    limit: int = 200,
    academy_id: UUID | None = None,
) -> list[User]:
    q = db.query(User).order_by(User.email)
    if academy_id is not None:
        q = q.filter(User.academy_id == academy_id)
    return q.limit(limit).all()


def get_user(db: Session, user_id: UUID) -> User | None:
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_email(db: Session, email: str) -> User | None:
    """Retorna usuário por e-mail (para login). Comparação case-insensitive."""
    if not email or not email.strip():
        return None
    return db.query(User).filter(User.email.ilike(email.strip())).first()


def set_password(db: Session, user_id: UUID, password_hash: str) -> User | None:
    """Atualiza o hash de senha do usuário. Retorna o User ou None se não existir."""
    user = get_user(db, user_id)
    if not user:
        return None
    user.password_hash = password_hash
    db.commit()
    db.refresh(user)
    return user


def create_user(
    db: Session,
    email: str,
    name: str | None = None,
    graduation: str | None = None,
    academy_id: UUID | None = None,
    password: str | None = None,
    role: str = "aluno",
) -> User:
    grad = graduation.strip() if graduation and graduation.strip() else None
    user = User(
        email=email.strip().lower(),
        name=name.strip() if name else None,
        graduation=grad,
        role=role,
        academy_id=academy_id,
        password_hash=hash_password(password) if password else None,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    logger.info("create_user", extra={"user_id": str(user.id), "email": user.email, "role": role})
    return user


def update_user(
    db: Session,
    user_id: UUID,
    name: str | None = None,
    graduation: str | None = None,
    academy_id: UUID | None = None,
    points_adjustment: int | None = None,
    role: str | None = None,
    password: str | None = None,
) -> User | None:
    user = get_user(db, user_id)
    if not user:
        return None
    if name is not None:
        user.name = name.strip() if name else None
    if graduation is not None:
        user.graduation = graduation.strip() if graduation and graduation.strip() else None
    if role is not None:
        user.role = role.strip() if role else "aluno"
    if academy_id is not None:
        user.academy_id = academy_id
    if points_adjustment is not None:
        user.points_adjustment = points_adjustment
    if password is not None and password.strip():
        user.password_hash = hash_password(password.strip())
    db.commit()
    db.refresh(user)
    logger.info("update_user", extra={"user_id": str(user_id), "role": user.role})
    return user


def delete_user(db: Session, user_id: UUID) -> bool:
    """Exclui o usuário e, em cascata, seus progressos, usos de missão e feedbacks."""
    user = get_user(db, user_id)
    if not user:
        return False
    # Exclusão em cascata no app: remove registros vinculados antes do usuário
    db.query(LessonProgress).filter(LessonProgress.user_id == user_id).delete(
        synchronize_session="fetch"
    )
    db.query(MissionUsage).filter(MissionUsage.user_id == user_id).delete(
        synchronize_session="fetch"
    )
    db.query(TechniqueExecution).filter(
        or_(
            TechniqueExecution.user_id == user_id,
            TechniqueExecution.opponent_id == user_id,
        )
    ).delete(synchronize_session="fetch")
    db.query(TrainingFeedback).filter(TrainingFeedback.user_id == user_id).delete(
        synchronize_session="fetch"
    )
    # Expirar o user para evitar estado inconsistente das collections
    db.expire(user)
    db.delete(user)
    db.commit()
    logger.info("delete_user", extra={"user_id": str(user_id)})
    return True
