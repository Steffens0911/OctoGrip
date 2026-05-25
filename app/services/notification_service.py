"""Serviço de notificações in-app: criar, listar, marcar como lida, broadcasts."""

from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

from sqlalchemy import func, select, update, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification
from app.models.user import User

logger = logging.getLogger(__name__)


async def create_notification(
    db: AsyncSession,
    *,
    user_id: UUID,
    type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> Notification:
    notif = Notification(user_id=user_id, type=type, title=title, body=body, data=data)
    db.add(notif)
    await db.commit()
    await db.refresh(notif)
    return notif


async def create_notifications_bulk(
    db: AsyncSession,
    *,
    user_ids: list[UUID],
    type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> int:
    if not user_ids:
        return 0
    notifs = [Notification(user_id=uid, type=type, title=title, body=body, data=data) for uid in user_ids]
    db.add_all(notifs)
    await db.commit()
    return len(notifs)


async def _get_academy_student_ids(
    db: AsyncSession,
    academy_id: UUID,
    exclude_user_id: UUID | None = None,
    roles: tuple[str, ...] = ("aluno",),
) -> list[UUID]:
    stmt = select(User.id).where(
        User.academy_id == academy_id,
        User.role.in_(roles),
    )
    if exclude_user_id:
        stmt = stmt.where(User.id != exclude_user_id)
    return list((await db.execute(stmt)).scalars().all())


async def create_notifications_for_academy_students(
    db: AsyncSession,
    *,
    academy_id: UUID,
    type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    exclude_user_id: UUID | None = None,
    roles: tuple[str, ...] = ("aluno",),
) -> int:
    """Envia notificações para membros da academia filtrando por roles.

    Por padrão só envia para alunos. Passe roles=("aluno", "professor") para
    incluir professores, ou roles=("aluno", "professor", "gerente_academia", "supervisor")
    para comunicados amplos.
    """
    user_ids = await _get_academy_student_ids(db, academy_id, exclude_user_id, roles=roles)
    return await create_notifications_bulk(db, user_ids=user_ids, type=type, title=title, body=body, data=data)


async def create_notifications_for_all_students(
    db: AsyncSession,
    *,
    type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    roles: tuple[str, ...] = ("aluno",),
) -> int:
    """Envia notificações para todos os usuários com os roles indicados.

    Por padrão só envia para alunos. Para comunicados globais do admin, passe
    roles=("aluno", "professor", "gerente_academia", "supervisor").
    """
    user_ids = list(
        (await db.execute(select(User.id).where(User.role.in_(roles)))).scalars().all()
    )
    return await create_notifications_bulk(db, user_ids=user_ids, type=type, title=title, body=body, data=data)


async def list_notifications(
    db: AsyncSession,
    user_id: UUID,
    *,
    limit: int = 50,
    offset: int = 0,
    unread_only: bool = False,
) -> list[Notification]:
    stmt = (
        select(Notification)
        .where(Notification.user_id == user_id, Notification.deleted.is_(False))
        .order_by(Notification.created_at.desc())
        .offset(max(0, offset))
        .limit(min(limit, 100))
    )
    if unread_only:
        stmt = stmt.where(Notification.read.is_(False))
    return list((await db.execute(stmt)).scalars().all())


async def get_unread_count(db: AsyncSession, user_id: UUID) -> int:
    result = await db.scalar(
        select(func.count(Notification.id)).where(
            Notification.user_id == user_id,
            Notification.read.is_(False),
            Notification.deleted.is_(False),
        )
    )
    return result or 0


async def delete_notification(db: AsyncSession, notification_id: UUID, user_id: UUID) -> bool:
    """Soft-delete de uma notificação: some apenas para o usuário que deletou."""
    result = await db.execute(
        update(Notification)
        .where(Notification.id == notification_id, Notification.user_id == user_id)
        .values(deleted=True)
    )
    await db.commit()
    return (result.rowcount or 0) > 0


async def mark_as_read(db: AsyncSession, notification_id: UUID, user_id: UUID) -> bool:
    result = await db.execute(
        update(Notification)
        .where(Notification.id == notification_id, Notification.user_id == user_id)
        .values(read=True)
    )
    await db.commit()
    return (result.rowcount or 0) > 0


async def mark_all_as_read(db: AsyncSession, user_id: UUID) -> int:
    result = await db.execute(
        update(Notification).where(Notification.user_id == user_id, Notification.read.is_(False)).values(read=True)
    )
    await db.commit()
    return result.rowcount or 0
