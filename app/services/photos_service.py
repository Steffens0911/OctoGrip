"""Serviço de banco de dados para OctoPhotos."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import and_, delete, func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache import app_cache
from app.models.academy_photo import AcademyPhoto, AcademyPhotoComment, AcademyPhotoLike, AcademyPhotoRestriction

_FEED_CACHE_TTL = 60  # segundos


def _feed_prefix(academy_id: uuid.UUID) -> str:
    return f"photos:feed:{academy_id}:"


async def invalidate_feed_cache(academy_id: uuid.UUID) -> None:
    """Invalida todo o cache de feed paginado de uma academia (bump de versão)."""
    await app_cache.bump_prefix_version(_feed_prefix(academy_id))


async def _feed_cache_key(academy_id: uuid.UUID, cursor: uuid.UUID | None) -> str:
    suffix = str(cursor) if cursor else "start"
    return await app_cache.versioned_key(_feed_prefix(academy_id), suffix)


def photo_to_cache_dict(photo: AcademyPhoto) -> dict:
    """Serializa um AcademyPhoto para dict cacheável (sem liked_by_me, que é por usuário)."""
    return {
        "id": str(photo.id),
        "academy_id": str(photo.academy_id),
        "author": {
            "id": str(photo.author.id),
            "name": photo.author.name,
            "avatar_url": getattr(photo.author, "avatar_url", None),
        },
        "image_url": photo.image_url,
        "thumbnail_url": photo.thumbnail_url,
        "caption": photo.caption,
        "status": photo.status,
        "likes_count": photo.likes_count,
        "comments_count": photo.comments_count,
        "is_system_post": photo.is_system_post,
        "system_post_type": photo.system_post_type,
        "system_post_ref_id": str(photo.system_post_ref_id) if photo.system_post_ref_id else None,
        "created_at": photo.created_at.isoformat(),
    }


async def count_user_photos(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID,
    user_id: uuid.UUID,
) -> int:
    """Conta posts ativos (não excluídos, não system) de um aluno em uma academia."""
    from sqlalchemy import func

    result = await db.execute(
        select(func.count())
        .select_from(AcademyPhoto)
        .where(
            AcademyPhoto.academy_id == academy_id,
            AcademyPhoto.author_id == user_id,
            AcademyPhoto.is_system_post.is_(False),
            AcademyPhoto.deleted_at.is_(None),
        )
    )
    return result.scalar_one()


async def get_academy_photo(db: AsyncSession, photo_id: uuid.UUID) -> AcademyPhoto | None:
    result = await db.execute(
        select(AcademyPhoto).where(AcademyPhoto.id == photo_id, AcademyPhoto.deleted_at.is_(None))
    )
    return result.scalar_one_or_none()


async def list_photos_feed(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID,
    limit: int = 20,
    before_id: uuid.UUID | None = None,
    author_id: uuid.UUID | None = None,
) -> tuple[list[AcademyPhoto], uuid.UUID | None]:
    """Feed paginado cursor-based. Retorna (itens, próximo cursor).

    Quando ``author_id`` é informado, retorna apenas posts daquele autor
    (usado na aba "Fotos" do perfil do aluno).
    """
    q = (
        select(AcademyPhoto)
        .where(AcademyPhoto.academy_id == academy_id, AcademyPhoto.deleted_at.is_(None))
        .order_by(AcademyPhoto.created_at.desc(), AcademyPhoto.id.desc())
    )
    if author_id is not None:
        q = q.where(AcademyPhoto.author_id == author_id)
    if before_id is not None:
        anchor = await get_academy_photo(db, before_id)
        if anchor:
            q = q.where(
                (AcademyPhoto.created_at < anchor.created_at)
                | (
                    (AcademyPhoto.created_at == anchor.created_at)
                    & (AcademyPhoto.id < anchor.id)
                )
            )
    q = q.limit(limit + 1)
    result = await db.execute(q)
    rows = list(result.scalars().all())
    next_cursor: uuid.UUID | None = None
    if len(rows) > limit:
        rows = rows[:limit]
        next_cursor = rows[-1].id
    return rows, next_cursor


async def list_photos_feed_cached(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID,
    limit: int = 20,
    before_id: uuid.UUID | None = None,
) -> tuple[list[dict], str | None]:
    """Feed paginado com cache Redis/in-memory. Retorna (lista de dicts cacheáveis, next_cursor str|None)."""
    cache_key = await _feed_cache_key(academy_id, before_id)
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached["items"], cached["next_cursor"]

    photos, next_cursor = await list_photos_feed(db, academy_id=academy_id, limit=limit, before_id=before_id)
    items = [photo_to_cache_dict(p) for p in photos]
    payload = {"items": items, "next_cursor": str(next_cursor) if next_cursor else None}
    await app_cache.set(cache_key, payload, ttl=_FEED_CACHE_TTL)
    return items, payload["next_cursor"]


async def create_photo(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID,
    author_id: uuid.UUID,
    raw_file_path: str,
    caption: str | None = None,
    is_system_post: bool = False,
    system_post_type: str | None = None,
    system_post_ref_id: uuid.UUID | None = None,
) -> AcademyPhoto:
    photo = AcademyPhoto(
        academy_id=academy_id,
        author_id=author_id,
        raw_file_path=raw_file_path,
        caption=caption,
        status="processing",
        is_system_post=is_system_post,
        system_post_type=system_post_type,
        system_post_ref_id=system_post_ref_id,
    )
    db.add(photo)
    await db.flush()
    await db.refresh(photo)
    return photo


async def create_system_post(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID,
    author_id: uuid.UUID,
    system_post_type: str,
    system_post_ref_id: uuid.UUID,
    caption: str | None = None,
) -> AcademyPhoto:
    """Cria post automático de conquista (troféu/faixa). Status 'ready' imediatamente — sem upload de imagem."""
    photo = AcademyPhoto(
        academy_id=academy_id,
        author_id=author_id,
        caption=caption,
        status="ready",
        is_system_post=True,
        system_post_type=system_post_type,
        system_post_ref_id=system_post_ref_id,
    )
    db.add(photo)
    await db.flush()
    await db.refresh(photo)
    return photo


async def mark_photo_ready(
    db: AsyncSession,
    *,
    photo_id: uuid.UUID,
    image_url: str,
    thumbnail_url: str,
) -> None:
    await db.execute(
        update(AcademyPhoto)
        .where(AcademyPhoto.id == photo_id)
        .values(image_url=image_url, thumbnail_url=thumbnail_url, status="ready", raw_file_path=None)
    )


async def mark_photo_failed(db: AsyncSession, *, photo_id: uuid.UUID) -> None:
    await db.execute(
        update(AcademyPhoto).where(AcademyPhoto.id == photo_id).values(status="failed")
    )


async def soft_delete_photo(db: AsyncSession, *, photo_id: uuid.UUID) -> None:
    await db.execute(
        update(AcademyPhoto)
        .where(AcademyPhoto.id == photo_id)
        .values(deleted_at=func.now())
    )


async def like_photo(
    db: AsyncSession, *, photo_id: uuid.UUID, user_id: uuid.UUID
) -> bool:
    """Cria curtida e incrementa contador. Retorna False se já curtiu."""
    existing = await db.execute(
        select(AcademyPhotoLike).where(
            AcademyPhotoLike.photo_id == photo_id,
            AcademyPhotoLike.user_id == user_id,
        )
    )
    if existing.scalar_one_or_none():
        return False
    db.add(AcademyPhotoLike(photo_id=photo_id, user_id=user_id))
    await db.execute(
        update(AcademyPhoto)
        .where(AcademyPhoto.id == photo_id)
        .values(likes_count=AcademyPhoto.likes_count + 1)
    )
    return True


async def unlike_photo(
    db: AsyncSession, *, photo_id: uuid.UUID, user_id: uuid.UUID
) -> bool:
    """Remove curtida e decrementa contador. Retorna False se não havia curtida."""
    result = await db.execute(
        delete(AcademyPhotoLike).where(
            AcademyPhotoLike.photo_id == photo_id,
            AcademyPhotoLike.user_id == user_id,
        )
    )
    if result.rowcount == 0:
        return False
    await db.execute(
        update(AcademyPhoto)
        .where(AcademyPhoto.id == photo_id, AcademyPhoto.likes_count > 0)
        .values(likes_count=AcademyPhoto.likes_count - 1)
    )
    return True


async def get_liked_photo_ids(
    db: AsyncSession, *, user_id: uuid.UUID, photo_ids: list[uuid.UUID]
) -> set[uuid.UUID]:
    """Retorna quais dos photo_ids o usuário já curtiu."""
    if not photo_ids:
        return set()
    result = await db.execute(
        select(AcademyPhotoLike.photo_id).where(
            AcademyPhotoLike.user_id == user_id,
            AcademyPhotoLike.photo_id.in_(photo_ids),
        )
    )
    return {row for (row,) in result.all()}


# --- Comentários ---


async def list_comments(
    db: AsyncSession,
    *,
    photo_id: uuid.UUID,
    limit: int = 50,
    before_id: uuid.UUID | None = None,
) -> list[AcademyPhotoComment]:
    q = (
        select(AcademyPhotoComment)
        .where(AcademyPhotoComment.photo_id == photo_id, AcademyPhotoComment.deleted_at.is_(None))
        .order_by(AcademyPhotoComment.created_at.asc())
    )
    if before_id is not None:
        anchor = await db.get(AcademyPhotoComment, before_id)
        if anchor:
            q = q.where(AcademyPhotoComment.created_at > anchor.created_at)
    q = q.limit(limit)
    result = await db.execute(q)
    return list(result.scalars().all())


async def create_comment(
    db: AsyncSession,
    *,
    photo_id: uuid.UUID,
    author_id: uuid.UUID,
    body: str,
) -> AcademyPhotoComment:
    comment = AcademyPhotoComment(photo_id=photo_id, author_id=author_id, body=body)
    db.add(comment)
    await db.execute(
        update(AcademyPhoto)
        .where(AcademyPhoto.id == photo_id)
        .values(comments_count=AcademyPhoto.comments_count + 1)
    )
    await db.flush()
    await db.refresh(comment)
    return comment


async def delete_comment(
    db: AsyncSession,
    *,
    comment_id: uuid.UUID,
) -> bool:
    """Soft-delete do comentário e decrementa contador. Retorna False se não encontrado."""
    result = await db.execute(
        select(AcademyPhotoComment).where(
            AcademyPhotoComment.id == comment_id,
            AcademyPhotoComment.deleted_at.is_(None),
        )
    )
    comment = result.scalar_one_or_none()
    if not comment:
        return False
    comment.deleted_at = func.now()
    await db.execute(
        update(AcademyPhoto)
        .where(AcademyPhoto.id == comment.photo_id, AcademyPhoto.comments_count > 0)
        .values(comments_count=AcademyPhoto.comments_count - 1)
    )
    return True


# --- Restrições ---


async def get_active_restriction(
    db: AsyncSession, *, academy_id: uuid.UUID, user_id: uuid.UUID
) -> AcademyPhotoRestriction | None:
    result = await db.execute(
        select(AcademyPhotoRestriction).where(
            AcademyPhotoRestriction.academy_id == academy_id,
            AcademyPhotoRestriction.user_id == user_id,
            AcademyPhotoRestriction.active.is_(True),
        )
    )
    return result.scalar_one_or_none()


async def list_restrictions(
    db: AsyncSession, *, academy_id: uuid.UUID, only_active: bool = True
) -> list[AcademyPhotoRestriction]:
    q = select(AcademyPhotoRestriction).where(
        AcademyPhotoRestriction.academy_id == academy_id
    )
    if only_active:
        q = q.where(AcademyPhotoRestriction.active.is_(True))
    q = q.order_by(AcademyPhotoRestriction.created_at.desc())
    result = await db.execute(q)
    return list(result.scalars().all())


async def create_restriction(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID,
    user_id: uuid.UUID,
    restricted_by: uuid.UUID,
    reason: str | None = None,
    expires_at: datetime | None = None,
) -> AcademyPhotoRestriction:
    restriction = AcademyPhotoRestriction(
        academy_id=academy_id,
        user_id=user_id,
        restricted_by=restricted_by,
        reason=reason,
        expires_at=expires_at,
    )
    db.add(restriction)
    await db.flush()
    await db.refresh(restriction)
    return restriction


async def patch_restriction(
    db: AsyncSession,
    *,
    restriction_id: uuid.UUID,
    active: bool | None = None,
    reason: str | None = None,
    expires_at: datetime | None = None,
) -> AcademyPhotoRestriction | None:
    result = await db.execute(
        select(AcademyPhotoRestriction).where(AcademyPhotoRestriction.id == restriction_id)
    )
    restriction = result.scalar_one_or_none()
    if not restriction:
        return None
    if active is not None:
        restriction.active = active
    if reason is not None:
        restriction.reason = reason
    if expires_at is not None:
        restriction.expires_at = expires_at
    await db.flush()
    await db.refresh(restriction)
    return restriction
