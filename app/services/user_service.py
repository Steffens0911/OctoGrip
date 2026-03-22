"""Serviços CRUD para User (painel desenvolvedores)."""
import logging
from uuid import UUID

from sqlalchemy import or_, select, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    LessonProgress,
    MissionUsage,
    TechniqueExecution,
    TrainingFeedback,
    TrainingVideoDailyView,
    User,
)
from app.core.exceptions import ConflictError, ForbiddenError, UserNotFoundError
from app.core.security import hash_password

logger = logging.getLogger(__name__)


async def get_user_or_raise(db: AsyncSession, user_id: UUID) -> User:
    """Retorna o usuário ou levanta UserNotFoundError."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise UserNotFoundError()
    return user


async def list_users(
    db: AsyncSession,
    limit: int = 50,
    offset: int = 0,
    academy_id: UUID | None = None,
) -> list[User]:
    """Lista usuários com paginação adequada."""
    stmt = select(User).order_by(User.email)
    if academy_id is not None:
        stmt = stmt.where(User.academy_id == academy_id)
    return (await db.execute(stmt.offset(offset).limit(limit))).scalars().all()


async def get_user(db: AsyncSession, user_id: UUID) -> User | None:
    return (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    """Retorna usuário por e-mail (para login). Comparação case-insensitive."""
    if not email or not email.strip():
        return None
    return (await db.execute(select(User).where(User.email.ilike(email.strip())))).scalar_one_or_none()


async def set_password(db: AsyncSession, user_id: UUID, password_hash: str) -> User | None:
    """Atualiza o hash de senha do usuário. Retorna o User ou None se não existir."""
    user = await get_user(db, user_id)
    if not user:
        return None
    user.password_hash = password_hash
    await db.commit()
    await db.refresh(user)
    return user


async def create_user(
    db: AsyncSession,
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
        password_hash=await hash_password(password) if password else None,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    logger.info("create_user", extra={"user_id": str(user.id), "email": user.email, "role": role})
    return user


async def update_user(
    db: AsyncSession,
    user_id: UUID,
    name: str | None = None,
    graduation: str | None = None,
    academy_id: UUID | None = None,
    points_adjustment: int | None = None,
    role: str | None = None,
    password: str | None = None,
    gallery_visible: bool | None = None,
) -> User | None:
    user = await get_user(db, user_id)
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
    if gallery_visible is not None:
        user.gallery_visible = gallery_visible
    if password is not None and password.strip():
        user.password_hash = await hash_password(password.strip())
    await db.commit()
    await db.refresh(user)

    # Se o admin/gerente alterou pontos manualmente, o level precisa acompanhar.
    if points_adjustment is not None:
        from app.services.leveling_service import refresh_user_level

        await refresh_user_level(db, user.id)

    logger.info("update_user", extra={"user_id": str(user_id), "role": user.role})
    return user


async def delete_user(db: AsyncSession, user_id: UUID) -> bool:
    """Exclui o usuário e, em cascata, seus progressos, usos de missão e feedbacks."""
    user = await get_user(db, user_id)
    if not user:
        return False
    await db.execute(sa_delete(TrainingVideoDailyView).where(TrainingVideoDailyView.user_id == user_id))
    await db.execute(sa_delete(LessonProgress).where(LessonProgress.user_id == user_id))
    await db.execute(sa_delete(MissionUsage).where(MissionUsage.user_id == user_id))
    await db.execute(
        sa_delete(TechniqueExecution).where(
            or_(
                TechniqueExecution.user_id == user_id,
                TechniqueExecution.opponent_id == user_id,
            )
        )
    )
    await db.execute(sa_delete(TrainingFeedback).where(TrainingFeedback.user_id == user_id))
    db.expire(user)
    await db.delete(user)
    await db.commit()
    logger.info("delete_user", extra={"user_id": str(user_id)})
    return True
