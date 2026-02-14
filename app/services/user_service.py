"""Serviços CRUD para User (painel desenvolvedores)."""
import logging
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import (
    LessonProgress,
    MissionUsage,
    TrainingFeedback,
    User,
)

logger = logging.getLogger(__name__)


def list_users(db: Session, limit: int = 200) -> list[User]:
    return db.query(User).order_by(User.email).limit(limit).all()


def get_user(db: Session, user_id: UUID) -> User | None:
    return db.query(User).filter(User.id == user_id).first()


def create_user(
    db: Session,
    email: str,
    name: str | None = None,
    academy_id: UUID | None = None,
) -> User:
    user = User(email=email.strip(), name=name.strip() if name else None, academy_id=academy_id)
    db.add(user)
    db.commit()
    db.refresh(user)
    logger.info("create_user", extra={"user_id": str(user.id), "email": user.email})
    return user


def update_user(
    db: Session,
    user_id: UUID,
    name: str | None = None,
    academy_id: UUID | None = None,
) -> User | None:
    user = get_user(db, user_id)
    if not user:
        return None
    if name is not None:
        user.name = name.strip() if name else None
    if academy_id is not None:
        user.academy_id = academy_id
    db.commit()
    db.refresh(user)
    logger.info("update_user", extra={"user_id": str(user_id)})
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
    db.query(TrainingFeedback).filter(TrainingFeedback.user_id == user_id).delete(
        synchronize_session="fetch"
    )
    # Expirar o user para evitar estado inconsistente das collections
    db.expire(user)
    db.delete(user)
    db.commit()
    logger.info("delete_user", extra={"user_id": str(user_id)})
    return True
