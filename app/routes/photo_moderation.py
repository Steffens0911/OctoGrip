"""Denunciar e bloquear no feed de fotos (OctoPhotos).

Incluído no router ANTES de ``photos`` para que ``/photos/reports`` e ``/photos/blocks`` não sejam
capturados por ``/photos/{photo_id}``.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import AppError, ForbiddenError, NotFoundError
from app.database import get_db
from app.models import User
from app.models.academy_photo import AcademyPhotoComment
from app.models.photo_moderation import AcademyPhotoReport
from app.routes.photos import _is_academy_member, _is_moderator, _require_octophotos
from app.schemas.photo_moderation import (
    BlockedUserRead,
    ReportAck,
    ReportCreate,
    ReportRead,
    ReportResolve,
)
from app.services import photo_moderation_service as moderation
from app.services.photos_service import get_academy_photo

router = APIRouter()


async def _require_member(db: AsyncSession, academy_id: uuid.UUID, user: User) -> None:
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(user, academy_id) and not _is_moderator(user):
        raise ForbiddenError("Acesso restrito a membros da academia.")


async def _require_moderator(db: AsyncSession, academy_id: uuid.UUID, user: User) -> None:
    await _require_octophotos(academy_id, db)
    if not _is_moderator(user) or (user.role != "administrador" and str(user.academy_id) != str(academy_id)):
        raise ForbiddenError("Apenas gerentes e administradores podem moderar denúncias.")


# --- Denunciar ---------------------------------------------------------------------------------


async def _report(
    db: AsyncSession,
    user: User,
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID | None,
    body: ReportCreate,
) -> ReportAck:
    await _require_member(db, academy_id, user)
    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id:
        raise NotFoundError("Post não encontrado.")

    comment = None
    if comment_id is not None:
        comment = (
            await db.execute(
                select(AcademyPhotoComment).where(
                    AcademyPhotoComment.id == comment_id,
                    AcademyPhotoComment.photo_id == photo_id,
                    AcademyPhotoComment.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if comment is None:
            raise NotFoundError("Comentário não encontrado.")

    author_id = comment.author_id if comment else photo.author_id
    if author_id == user.id:
        raise AppError("Você não pode denunciar o seu próprio conteúdo.", status_code=400)

    report, created = await moderation.create_report(
        db,
        academy_id=academy_id,
        reporter=user,
        photo=photo,
        comment=comment,
        reason=body.reason,
        details=body.details,
    )
    if created:
        await moderation.notify_moderators(db, academy_id=academy_id, report=report)
    return ReportAck(id=report.id, status=report.status, already_reported=not created)


@router.post("/{academy_id}/photos/{photo_id}/report", response_model=ReportAck, status_code=201)
async def report_photo(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    body: ReportCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Denuncia um post. O conteúdo some do feed de quem denunciou e os gestores são avisados."""
    return await _report(db, current_user, academy_id, photo_id, None, body)


@router.post("/{academy_id}/photos/{photo_id}/comments/{comment_id}/report", response_model=ReportAck, status_code=201)
async def report_comment(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    body: ReportCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Denuncia um comentário."""
    return await _report(db, current_user, academy_id, photo_id, comment_id, body)


# --- Moderação (gerente/administrador) ---------------------------------------------------------


@router.get("/{academy_id}/photos/reports", response_model=list[ReportRead])
async def list_photo_reports(
    academy_id: uuid.UUID,
    status: str | None = Query("open", pattern="^(open|removed|dismissed)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_moderator(db, academy_id, current_user)
    return await moderation.list_reports(db, academy_id=academy_id, status=status)


@router.patch("/{academy_id}/photos/reports/{report_id}", response_model=ReportRead)
async def resolve_photo_report(
    academy_id: uuid.UUID,
    report_id: uuid.UUID,
    body: ReportResolve,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """``dismiss`` mantém o conteúdo; ``remove`` apaga o post ou comentário denunciado."""
    await _require_moderator(db, academy_id, current_user)
    report = await db.get(AcademyPhotoReport, report_id)
    if not report or report.academy_id != academy_id:
        raise NotFoundError("Denúncia não encontrada.")
    await moderation.resolve_report(db, report=report, moderator=current_user, action=body.action)
    rows = await moderation.list_reports(db, academy_id=academy_id, status=None)
    return next(r for r in rows if r["id"] == report_id)


# --- Bloquear ----------------------------------------------------------------------------------


@router.get("/{academy_id}/photos/blocks", response_model=list[BlockedUserRead])
async def list_my_blocks(
    academy_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_member(db, academy_id, current_user)
    return await moderation.list_blocked_users(db, blocker_id=current_user.id)


@router.put("/{academy_id}/photos/blocks/{user_id}", status_code=204)
async def block_photo_user(
    academy_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Bloqueia um usuário: seus posts e comentários deixam de aparecer para você."""
    await _require_member(db, academy_id, current_user)
    if user_id == current_user.id:
        raise AppError("Você não pode bloquear a si mesmo.", status_code=400)
    target = await db.get(User, user_id)
    if not target or str(target.academy_id) != str(academy_id):
        raise NotFoundError("Usuário não encontrado nesta academia.")
    await moderation.block_user(db, blocker_id=current_user.id, blocked_id=user_id)
    return Response(status_code=204)


@router.delete("/{academy_id}/photos/blocks/{user_id}", status_code=204)
async def unblock_photo_user(
    academy_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_member(db, academy_id, current_user)
    await moderation.unblock_user(db, blocker_id=current_user.id, blocked_id=user_id)
    return Response(status_code=204)
