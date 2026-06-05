"""Serviços CRUD para User (painel desenvolvedores)."""

import logging
from uuid import UUID

from sqlalchemy import delete as sa_delete
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, UserNotFoundError
from app.core.security import hash_password
from app.models import (
    LessonProgress,
    MissionUsage,
    TechniqueExecution,
    TrainingFeedback,
    TrainingVideoDailyView,
    User,
)
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    user_entity_snapshot_row,
    write_audit_log,
)

logger = logging.getLogger(__name__)

_ENTITY_USER = "User"
UNSET = object()


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
    search: str | None = None,
    graduation: str | None = None,
) -> list[User]:
    """Lista usuários com paginação adequada."""
    stmt = select(User).order_by(User.email)
    if academy_id is not None:
        stmt = stmt.where(User.academy_id == academy_id)
    if search:
        s = f"%{search.strip()}%"
        stmt = stmt.where(or_(User.email.ilike(s), User.name.ilike(s)))
    if graduation:
        stmt = stmt.where(User.graduation == graduation)
    return (await db.execute(stmt.offset(offset).limit(limit))).scalars().all()


async def get_user(db: AsyncSession, user_id: UUID) -> User | None:
    return (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    """Procura e-mail na tabela `users` globalmente (sem filtrar por academia). Comparação case-insensitive."""
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
    *,
    audit_user_id: UUID | None = None,
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
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_USER,
        entity_id=user.id,
        old_data=None,
        new_data=user_entity_snapshot_row(user),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(user)
    logger.info("create_user", extra={"user_id": str(user.id), "email": user.email, "role": role})
    return user


async def update_user(
    db: AsyncSession,
    user_id: UUID,
    name: str | None = None,
    email: str | None = None,
    graduation: str | None = None,
    academy_id: UUID | None = None,
    points_adjustment: int | None = None,
    avatar_url: str | None = None,
    role: str | None = None,
    password: str | None = None,
    gallery_visible: bool | None = None,
    account_frozen: bool | None | object = UNSET,
    account_freeze_reason: str | None | object = UNSET,
    *,
    audit_user_id: UUID | None = None,
) -> User | None:
    user = await get_user(db, user_id)
    if not user:
        return None
    before = user_entity_snapshot_row(user)
    _old_frozen = user.account_frozen
    _old_graduation = user.graduation
    if email is not None:
        normalized = email.strip().lower()
        if normalized != (user.email or "").lower():
            other = await get_user_by_email(db, normalized)
            if other is not None and other.id != user.id:
                raise ConflictError("E-mail já cadastrado por outro usuário (único em todo o sistema).")
        user.email = normalized
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
    if avatar_url is not None:
        user.avatar_url = avatar_url.strip() if avatar_url and avatar_url.strip() else None
    if gallery_visible is not None:
        user.gallery_visible = gallery_visible
    if account_frozen is not UNSET:
        user.account_frozen = bool(account_frozen)
    if account_freeze_reason is not UNSET:
        if account_freeze_reason is None or (
            isinstance(account_freeze_reason, str) and not str(account_freeze_reason).strip()
        ):
            user.account_freeze_reason = None
        else:
            user.account_freeze_reason = str(account_freeze_reason).strip()
    if password is not None and password.strip():
        user.password_hash = await hash_password(password.strip())
    await db.flush()
    await db.refresh(user)
    after = user_entity_snapshot_row(user)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_USER,
            entity_id=user_id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(user)

    # Se o admin/gerente alterou pontos manualmente, o level precisa acompanhar.
    if points_adjustment is not None:
        from app.services.leveling_service import refresh_user_level

        await refresh_user_level(db, user.id)

    # Notifica o aluno se o status de congelamento mudou (fire-and-forget).
    if account_frozen is not UNSET and bool(account_frozen) != _old_frozen:
        try:
            from app.services.notification_service import create_notification

            if bool(account_frozen):
                reason = (
                    account_freeze_reason
                    if account_freeze_reason is not UNSET and isinstance(account_freeze_reason, str)
                    else ""
                )
                body_text = "Sua conta foi congelada."
                if reason and reason.strip():
                    body_text = f"Sua conta foi congelada. Motivo: {reason.strip()}"
                await create_notification(
                    db,
                    user_id=user_id,
                    type="account_frozen",
                    title="Conta congelada 🔒",
                    body=body_text,
                )
            else:
                await create_notification(
                    db,
                    user_id=user_id,
                    type="account_unfrozen",
                    title="Conta reativada ✅",
                    body="Sua conta foi reativada e está liberada para uso.",
                )
        except Exception:
            logger.exception("update_user: erro ao criar notificação in-app de freeze")

    # Post automático de promoção de faixa no OctoPhotos (opt-out).
    new_graduation = user.graduation
    graduation_changed = graduation is not None and new_graduation and new_graduation != _old_graduation
    if graduation_changed and user.academy_id:
        try:
            from app.services.academy_service import get_academy
            from app.services.photos_service import create_system_post, invalidate_feed_cache

            academy = await get_academy(db, user.academy_id)
            if academy and getattr(academy, "octophotos_enabled", False):
                _belt_labels = {
                    "white": "Branca",
                    "blue": "Azul",
                    "purple": "Roxa",
                    "brown": "Marrom",
                    "black": "Preta",
                }
                belt_label = _belt_labels.get(new_graduation.lower(), new_graduation.capitalize())
                user_name = (user.name or "Aluno").strip()
                caption = f"{user_name} foi graduado para faixa {belt_label}! 🎉"
                await create_system_post(
                    db,
                    academy_id=user.academy_id,
                    author_id=user_id,
                    system_post_type="belt_promotion",
                    system_post_ref_id=user_id,
                    caption=caption,
                )
                await db.commit()
                await invalidate_feed_cache(user.academy_id)
        except Exception:
            logger.exception("update_user: erro ao criar post automático de faixa OctoPhotos")

    logger.info("update_user", extra={"user_id": str(user_id), "role": user.role})
    return user


async def delete_user(
    db: AsyncSession,
    user_id: UUID,
    *,
    audit_user_id: UUID | None = None,
) -> bool:
    """Exclui o usuário e, em cascata, seus progressos, usos de missão e feedbacks."""
    user = await get_user(db, user_id)
    if not user:
        return False
    before = user_entity_snapshot_row(user)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_USER,
        entity_id=user_id,
        old_data=before,
        new_data=None,
        user_id=audit_user_id,
    )
    await db.execute(sa_delete(TrainingVideoDailyView).where(TrainingVideoDailyView.user_id == user_id))
    await db.execute(sa_delete(LessonProgress).where(LessonProgress.user_id == user_id))
    await db.execute(sa_delete(MissionUsage).where(MissionUsage.user_id == user_id))
    await db.execute(sa_delete(TechniqueExecution).where(TechniqueExecution.user_id == user_id))
    await db.execute(sa_delete(TrainingFeedback).where(TrainingFeedback.user_id == user_id))
    db.expire(user)
    await db.delete(user)
    await db.commit()
    logger.info("delete_user", extra={"user_id": str(user_id)})
    return True
