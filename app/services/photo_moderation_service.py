"""Denúncias e bloqueios do feed de fotos: regras de negócio (sem HTTP)."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime

from sqlalchemy import delete, func, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User
from app.models.academy_photo import AcademyPhoto, AcademyPhotoComment
from app.models.photo_moderation import AcademyPhotoReport, UserBlock
from app.services.notification_service import create_notification
from app.services.photos_service import delete_comment, invalidate_feed_cache, soft_delete_photo

logger = logging.getLogger(__name__)

# Quem recebe aviso de denúncia nova (e pode agir sobre ela).
MODERATOR_ROLES = ("administrador", "gerente_academia")


@dataclass
class HiddenContent:
    """O que o usuário não deve ver: autores que bloqueou e o que ele mesmo denunciou."""

    blocked_author_ids: set[uuid.UUID] = field(default_factory=set)
    reported_photo_ids: set[uuid.UUID] = field(default_factory=set)
    reported_comment_ids: set[uuid.UUID] = field(default_factory=set)


async def get_hidden_content(db: AsyncSession, user_id: uuid.UUID) -> HiddenContent:
    blocked = (await db.execute(select(UserBlock.blocked_id).where(UserBlock.blocker_id == user_id))).scalars().all()
    rows = (
        await db.execute(
            select(AcademyPhotoReport.photo_id, AcademyPhotoReport.comment_id).where(
                AcademyPhotoReport.reporter_id == user_id
            )
        )
    ).all()
    return HiddenContent(
        blocked_author_ids=set(blocked),
        reported_photo_ids={photo_id for photo_id, comment_id in rows if comment_id is None},
        reported_comment_ids={comment_id for _, comment_id in rows if comment_id is not None},
    )


# --- Denúncias ---------------------------------------------------------------------------------


async def create_report(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID,
    reporter: User,
    photo: AcademyPhoto,
    comment: AcademyPhotoComment | None,
    reason: str,
    details: str | None,
) -> tuple[AcademyPhotoReport, bool]:
    """Registra a denúncia. Denunciar o mesmo alvo de novo devolve a existente (``False`` = já existia)."""
    stmt = select(AcademyPhotoReport).where(AcademyPhotoReport.reporter_id == reporter.id)
    if comment is None:
        stmt = stmt.where(AcademyPhotoReport.photo_id == photo.id, AcademyPhotoReport.comment_id.is_(None))
    else:
        stmt = stmt.where(AcademyPhotoReport.comment_id == comment.id)
    existing = (await db.execute(stmt)).scalar_one_or_none()
    if existing:
        return existing, False

    report = AcademyPhotoReport(
        academy_id=academy_id,
        reporter_id=reporter.id,
        photo_id=photo.id,
        comment_id=comment.id if comment else None,
        reason=reason,
        details=(details or "").strip() or None,
    )
    db.add(report)
    try:
        await db.commit()
    except IntegrityError:  # duas denúncias simultâneas do mesmo alvo
        await db.rollback()
        again = (await db.execute(stmt)).scalar_one()
        return again, False
    await db.refresh(report)
    return report, True


async def notify_moderators(db: AsyncSession, *, academy_id: uuid.UUID, report: AcademyPhotoReport) -> None:
    """Aviso dentro do app para gestores da academia. Falha aqui nunca derruba a denúncia."""
    try:
        moderator_ids = (
            (await db.execute(select(User.id).where(User.academy_id == academy_id, User.role.in_(MODERATOR_ROLES))))
            .scalars()
            .all()
        )
        what = "um comentário" if report.comment_id else "um post"
        for uid in moderator_ids:
            await create_notification(
                db,
                user_id=uid,
                type="photo_report",
                title="Nova denúncia no feed",
                body=f"Alguém denunciou {what} no feed de fotos da academia.",
                data={"academy_id": str(academy_id), "report_id": str(report.id)},
            )
    except Exception:
        logger.warning("Falha ao notificar moderadores da denúncia %s", report.id, exc_info=True)
        await db.rollback()


async def list_reports(db: AsyncSession, *, academy_id: uuid.UUID, status: str | None, limit: int = 100) -> list[dict]:
    """Denúncias da academia, mais novas primeiro, com o resumo do alvo para o moderador decidir."""
    stmt = select(AcademyPhotoReport).where(AcademyPhotoReport.academy_id == academy_id)
    if status:
        stmt = stmt.where(AcademyPhotoReport.status == status)
    reports = (await db.execute(stmt.order_by(AcademyPhotoReport.created_at.desc()).limit(limit))).scalars().all()
    if not reports:
        return []

    photos = {
        p.id: p
        for p in (
            await db.execute(select(AcademyPhoto).where(AcademyPhoto.id.in_({r.photo_id for r in reports})))
        ).scalars()
    }
    comment_ids = {r.comment_id for r in reports if r.comment_id}
    comments = (
        {
            c.id: c
            for c in (
                await db.execute(select(AcademyPhotoComment).where(AcademyPhotoComment.id.in_(comment_ids)))
            ).scalars()
        }
        if comment_ids
        else {}
    )
    user_ids = (
        {r.reporter_id for r in reports}
        | {p.author_id for p in photos.values()}
        | {c.author_id for c in comments.values()}
    )
    names = {u.id: u.name for u in (await db.execute(select(User).where(User.id.in_(user_ids)))).scalars()}

    counts: dict[tuple[uuid.UUID, uuid.UUID | None], int] = {}
    for r in reports:
        key = (r.photo_id, r.comment_id)
        counts[key] = counts.get(key, 0) + 1

    out: list[dict] = []
    for r in reports:
        photo = photos.get(r.photo_id)
        comment = comments.get(r.comment_id) if r.comment_id else None
        if comment is not None:
            author_id, text_, thumb, removed = comment.author_id, comment.body, None, comment.deleted_at is not None
        else:
            author_id = photo.author_id if photo else None
            text_ = photo.caption if photo else None
            thumb = photo.thumbnail_url if photo else None
            removed = photo is None or photo.deleted_at is not None
        out.append(
            {
                "id": r.id,
                "status": r.status,
                "reason": r.reason,
                "details": r.details,
                "created_at": r.created_at,
                "reporter_name": names.get(r.reporter_id),
                "photo_id": r.photo_id,
                "comment_id": r.comment_id,
                "target_type": "comment" if r.comment_id else "photo",
                "target_author_id": author_id,
                "target_author_name": names.get(author_id) if author_id else None,
                "target_text": text_,
                "target_thumbnail_url": thumb,
                "target_removed": removed,
                "reports_on_target": counts[(r.photo_id, r.comment_id)],
            }
        )
    return out


async def resolve_report(
    db: AsyncSession, *, report: AcademyPhotoReport, moderator: User, action: str
) -> AcademyPhotoReport:
    """``dismiss`` mantém o conteúdo; ``remove`` apaga o post ou comentário. Vale para todas as
    denúncias abertas sobre o mesmo alvo."""
    if action == "remove":
        if report.comment_id:
            await delete_comment(db, comment_id=report.comment_id)
        else:
            await soft_delete_photo(db, photo_id=report.photo_id)
    new_status = "removed" if action == "remove" else "dismissed"

    same_target = AcademyPhotoReport.photo_id == report.photo_id
    same_target = same_target & (
        AcademyPhotoReport.comment_id.is_(None)
        if report.comment_id is None
        else AcademyPhotoReport.comment_id == report.comment_id
    )
    await db.execute(
        update(AcademyPhotoReport)
        .where(same_target, AcademyPhotoReport.status == "open")
        .values(status=new_status, resolved_by=moderator.id, resolved_at=datetime.now(UTC))
    )
    await db.commit()
    await db.refresh(report)
    await invalidate_feed_cache(report.academy_id)
    return report


# --- Bloqueios ---------------------------------------------------------------------------------


async def block_user(db: AsyncSession, *, blocker_id: uuid.UUID, blocked_id: uuid.UUID) -> None:
    await db.execute(pg_insert(UserBlock).values(blocker_id=blocker_id, blocked_id=blocked_id).on_conflict_do_nothing())
    await db.commit()


async def unblock_user(db: AsyncSession, *, blocker_id: uuid.UUID, blocked_id: uuid.UUID) -> None:
    await db.execute(delete(UserBlock).where(UserBlock.blocker_id == blocker_id, UserBlock.blocked_id == blocked_id))
    await db.commit()


async def list_blocked_users(db: AsyncSession, *, blocker_id: uuid.UUID) -> list[dict]:
    rows = (
        await db.execute(
            select(UserBlock.blocked_id, UserBlock.created_at, User.name, User.avatar_url)
            .join(User, User.id == UserBlock.blocked_id)
            .where(UserBlock.blocker_id == blocker_id)
            .order_by(UserBlock.created_at.desc())
        )
    ).all()
    return [{"user_id": uid, "name": name, "avatar_url": avatar, "created_at": at} for uid, at, name, avatar in rows]


async def count_open_reports(db: AsyncSession, *, academy_id: uuid.UUID) -> int:
    return (
        await db.execute(
            select(func.count())
            .select_from(AcademyPhotoReport)
            .where(AcademyPhotoReport.academy_id == academy_id, AcademyPhotoReport.status == "open")
        )
    ).scalar_one()
