"""Rotas de notificações in-app: listar, contar não lidas, marcar lidas, comunicados."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import ForbiddenError
from app.database import get_db
from app.models import User
from app.schemas.notification_schemas import AnnouncementCreate, NotificationRead
from app.services.notification_service import (
    create_notifications_for_academy_students,
    create_notifications_for_all_students,
    get_unread_count,
    list_notifications,
    mark_all_as_read,
    mark_as_read,
)

router = APIRouter()

_STAFF_ROLES = {"supervisor", "gerente_academia", "administrador"}


@router.get("", response_model=list[NotificationRead])
async def notifications_list(
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    unread_only: bool = Query(False),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista notificações do usuário logado, ordenadas da mais recente à mais antiga."""
    return await list_notifications(
        db, current_user.id, limit=limit, offset=offset, unread_only=unread_only
    )


@router.get("/unread-count")
async def notifications_unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retorna a contagem de notificações não lidas do usuário logado."""
    return {"count": await get_unread_count(db, current_user.id)}


@router.post("/{notification_id}/read", status_code=204)
async def notification_mark_read(
    notification_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Marca uma notificação específica como lida."""
    await mark_as_read(db, notification_id, current_user.id)


@router.post("/read-all", status_code=204)
async def notifications_read_all(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Marca todas as notificações do usuário como lidas."""
    await mark_all_as_read(db, current_user.id)


@router.post("/announcement", status_code=204)
async def create_announcement(
    body: AnnouncementCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Envia comunicado como notificação in-app.
    Gestor/supervisor: apenas alunos da própria academia.
    Admin: todos os alunos do sistema.
    """
    if current_user.role not in _STAFF_ROLES:
        raise ForbiddenError("Apenas gestores e administradores podem enviar comunicados.")

    if current_user.role == "administrador":
        await create_notifications_for_all_students(
            db,
            type="announcement_global",
            title=body.title,
            body=body.body,
        )
    else:
        if not current_user.academy_id:
            raise ForbiddenError("Você não está associado a nenhuma academia.")
        await create_notifications_for_academy_students(
            db,
            academy_id=current_user.academy_id,
            type="announcement_academy",
            title=body.title,
            body=body.body,
        )
