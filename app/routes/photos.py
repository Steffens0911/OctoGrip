"""Endpoints OctoPhotos — feed de fotos por academia (feature premium)."""

from __future__ import annotations

import io
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import StreamingResponse
from PIL import Image, ImageDraw, ImageFont
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import ForbiddenError, NotFoundError
from app.database import get_db
from app.models import User
from app.schemas.photos import (
    CommentCreate,
    CommentRead,
    MentionSuggestion,
    PhotoFeedPage,
    PhotoRead,
    RestrictionCreate,
    RestrictionPatch,
    RestrictionRead,
)
from app.services.academy_service import get_academy as _get_academy
from app.services.notification_service import create_notification
from app.services.photos_service import (
    count_user_photos,
    create_comment,
    create_photo,
    create_restriction,
    delete_comment,
    extract_mention_ids,
    extract_mentions,
    get_academy_photo,
    get_active_restriction,
    get_liked_photo_ids,
    invalidate_feed_cache,
    like_photo,
    list_comments,
    list_photos_feed_cached,
    list_restrictions,
    patch_restriction,
    resolve_mention_user_ids,
    soft_delete_photo,
    unlike_photo,
)

router = APIRouter()

_MEDIA_ROOT = (Path(__file__).resolve().parent.parent.parent / "app_media").resolve()
_MAX_UPLOAD_MB = 10
_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}

# Roles com poder de moderação na academia
_MOD_ROLES = {"administrador", "gerente_academia"}


async def _require_octophotos(academy_id: uuid.UUID, db: AsyncSession) -> None:
    """Levanta 403 se a feature não estiver habilitada para a academia."""
    academy = await _get_academy(db, academy_id)
    if not academy:
        raise NotFoundError("Academia não encontrada.")
    if not academy.octophotos_enabled:
        raise ForbiddenError("feature_requires_premium")


def _is_academy_member(user: User, academy_id: uuid.UUID) -> bool:
    return str(user.academy_id) == str(academy_id)


def _is_moderator(user: User) -> bool:
    return user.role in _MOD_ROLES


def _photo_to_read(photo, liked_ids: set[uuid.UUID]) -> PhotoRead:
    from app.schemas.photos import PhotoAuthor

    return PhotoRead(
        id=photo.id,
        academy_id=photo.academy_id,
        author=PhotoAuthor(
            id=photo.author.id,
            name=photo.author.name,
            avatar_url=getattr(photo.author, "avatar_url", None),
        ),
        image_url=photo.image_url,
        thumbnail_url=photo.thumbnail_url,
        caption=photo.caption,
        status=photo.status,
        likes_count=photo.likes_count,
        comments_count=photo.comments_count,
        liked_by_me=photo.id in liked_ids,
        is_system_post=photo.is_system_post,
        system_post_type=photo.system_post_type,
        system_post_ref_id=photo.system_post_ref_id,
        created_at=photo.created_at,
    )


def _cached_dict_to_read(item: dict, liked_ids: set[uuid.UUID]) -> PhotoRead:
    """Converte dict cacheado para PhotoRead, injetando liked_by_me por usuário."""
    from datetime import datetime as _dt

    from app.schemas.photos import PhotoAuthor

    photo_id = uuid.UUID(item["id"])
    return PhotoRead(
        id=photo_id,
        academy_id=uuid.UUID(item["academy_id"]),
        author=PhotoAuthor(
            id=uuid.UUID(item["author"]["id"]),
            name=item["author"]["name"],
            avatar_url=item["author"]["avatar_url"],
        ),
        image_url=item["image_url"],
        thumbnail_url=item["thumbnail_url"],
        caption=item["caption"],
        status=item["status"],
        likes_count=item["likes_count"],
        comments_count=item.get("comments_count", 0),
        liked_by_me=photo_id in liked_ids,
        is_system_post=item["is_system_post"],
        system_post_type=item["system_post_type"],
        system_post_ref_id=uuid.UUID(item["system_post_ref_id"]) if item["system_post_ref_id"] else None,
        created_at=_dt.fromisoformat(item["created_at"]),
    )


# ---------------------------------------------------------------------------
# Feed
# ---------------------------------------------------------------------------


@router.get("/{academy_id}/photos", response_model=PhotoFeedPage)
async def photos_feed(
    academy_id: uuid.UUID,
    cursor: uuid.UUID | None = Query(None, description="ID do último item recebido (paginação cursor-based)"),
    limit: int = Query(20, ge=1, le=50),
    author_id: uuid.UUID | None = Query(None, description="Filtra posts de um autor específico (perfil do aluno)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    if author_id is not None:
        # Feed filtrado por autor — não usa cache pois é específico por aluno
        from app.services.photos_service import list_photos_feed

        photos, next_cursor = await list_photos_feed(
            db, academy_id=academy_id, limit=limit, before_id=cursor, author_id=author_id
        )
        photo_ids_typed = [p.id for p in photos]
        liked_ids = await get_liked_photo_ids(db, user_id=current_user.id, photo_ids=photo_ids_typed)
        items = [_photo_to_read(p, liked_ids) for p in photos]
        return PhotoFeedPage(items=items, next_cursor=str(next_cursor) if next_cursor else None)

    # Feed geral — usa cache (dados sem liked_by_me; injetado por usuário após)
    cached_items, next_cursor = await list_photos_feed_cached(db, academy_id=academy_id, limit=limit, before_id=cursor)
    photo_ids = [uuid.UUID(item["id"]) for item in cached_items]
    liked_ids = await get_liked_photo_ids(db, user_id=current_user.id, photo_ids=photo_ids)
    items = [_cached_dict_to_read(item, liked_ids) for item in cached_items]
    return PhotoFeedPage(items=items, next_cursor=next_cursor)


# ---------------------------------------------------------------------------
# Criar post
# ---------------------------------------------------------------------------


@router.post("/{academy_id}/photos", response_model=PhotoRead, status_code=201)
async def create_post(
    academy_id: uuid.UUID,
    file: UploadFile = File(...),
    caption: str | None = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    # Validar tipo de arquivo
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise ForbiddenError("Tipo de arquivo não permitido. Use JPEG, PNG ou WebP.")

    # Validar tamanho
    content = await file.read()
    if len(content) > _MAX_UPLOAD_MB * 1024 * 1024:
        raise ForbiddenError(f"Arquivo muito grande. Máximo {_MAX_UPLOAD_MB}MB.")

    # Verificar restrição de postagem e quota — moderadores são isentos
    if not _is_moderator(current_user):
        restriction = await get_active_restriction(db, academy_id=academy_id, user_id=current_user.id)
        if restriction:
            raise ForbiddenError("Você está temporariamente impedido de postar nesta academia.")

        academy = await _get_academy(db, academy_id)
        quota = academy.user_photos_quota
        current_count = await count_user_photos(db, academy_id=academy_id, user_id=current_user.id)
        if current_count >= quota:
            raise ForbiddenError(
                f"Você atingiu o limite de {quota} foto{'s' if quota != 1 else ''}. "
                "Exclua uma foto antiga para publicar uma nova."
            )

    # Validar caption
    if caption and len(caption) > 280:
        raise ForbiddenError("Legenda muito longa. Máximo 280 caracteres.")

    # Salvar arquivo bruto
    raw_dir = _MEDIA_ROOT / "photos_raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    raw_path = raw_dir / f"{uuid.uuid4()}_raw{Path(file.filename or 'photo.jpg').suffix}"
    raw_path.write_bytes(content)

    # Criar registro no banco (status=processing)
    photo = await create_photo(
        db,
        academy_id=academy_id,
        author_id=current_user.id,
        raw_file_path=str(raw_path),
        caption=caption,
    )
    await db.commit()
    await db.refresh(photo)
    await invalidate_feed_cache(academy_id)

    # Disparar task Celery de resize em background
    from app.tasks.photo_tasks import process_photo_upload

    process_photo_upload.delay(str(photo.id), str(raw_path))

    return _photo_to_read(photo, set())


# ---------------------------------------------------------------------------
# Deletar post
# ---------------------------------------------------------------------------


@router.delete("/{academy_id}/photos/{photo_id}", status_code=204)
async def delete_post(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id:
        raise NotFoundError("Post não encontrado.")

    is_author = photo.author_id == current_user.id
    if not is_author and not _is_moderator(current_user):
        raise ForbiddenError("Você não tem permissão para deletar este post.")

    await soft_delete_photo(db, photo_id=photo_id)
    await db.commit()
    await invalidate_feed_cache(academy_id)
    return None


# ---------------------------------------------------------------------------
# Curtir / descurtir
# ---------------------------------------------------------------------------


@router.post("/{academy_id}/photos/{photo_id}/like", status_code=204)
async def like_post(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id:
        raise NotFoundError("Post não encontrado.")

    await like_photo(db, photo_id=photo_id, user_id=current_user.id)
    await db.commit()
    return None


@router.delete("/{academy_id}/photos/{photo_id}/like", status_code=204)
async def unlike_post(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id:
        raise NotFoundError("Post não encontrado.")

    await unlike_photo(db, photo_id=photo_id, user_id=current_user.id)
    await db.commit()
    return None


# ---------------------------------------------------------------------------
# Export com watermark
# ---------------------------------------------------------------------------


@router.get("/{academy_id}/photos/{photo_id}/export")
async def export_photo(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retorna a foto com watermark: nome da academia + 'OCTOGRIP' no rodapé."""
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id or photo.status != "ready":
        raise NotFoundError("Post não encontrado ou ainda em processamento.")

    academy = await _get_academy(db, academy_id)
    academy_name = academy.name if academy else "Academia"

    # Construir path local da imagem original
    image_filename = Path(photo.image_url).name if photo.image_url else None
    if not image_filename:
        raise NotFoundError("Imagem não disponível.")
    image_path = _MEDIA_ROOT / "photos" / image_filename
    if not image_path.exists():
        raise NotFoundError("Arquivo de imagem não encontrado.")

    output = _compose_watermark(str(image_path), academy_name)
    return StreamingResponse(io.BytesIO(output), media_type="image/jpeg")


def _compose_watermark(image_path: str, academy_name: str) -> bytes:
    """Compõe watermark: faixa escura no rodapé + nome da academia à esquerda + OCTOGRIP à direita."""
    _ACCENT = (78, 207, 138)  # #4ecf8a
    _BANNER_HEIGHT = 48
    _PADDING = 16

    with Image.open(image_path) as img:
        img = img.convert("RGB")
        w, h = img.size

        banner = Image.new("RGBA", (w, _BANNER_HEIGHT), (0, 0, 0, 180))
        draw = ImageDraw.Draw(banner)

        try:
            font = ImageFont.truetype("arial.ttf", 18)
        except OSError:
            font = ImageFont.load_default()

        draw.text((_PADDING, 14), academy_name, font=font, fill=_ACCENT)
        brand_text = "OCTOGRIP"
        bbox = draw.textbbox((0, 0), brand_text, font=font)
        brand_w = bbox[2] - bbox[0]
        draw.text((w - brand_w - _PADDING, 14), brand_text, font=font, fill=_ACCENT)

        result = img.copy()
        banner_rgb = Image.new("RGB", banner.size)
        banner_rgb.paste(banner, mask=banner.split()[3])
        result.paste(banner_rgb, (0, h - _BANNER_HEIGHT))

        buf = io.BytesIO()
        result.save(buf, "JPEG", quality=90)
        return buf.getvalue()


# ---------------------------------------------------------------------------
# Sugestões de @menção
# ---------------------------------------------------------------------------


@router.get("/{academy_id}/photos/mention-suggestions", response_model=list[MentionSuggestion])
async def mention_suggestions(
    academy_id: uuid.UUID,
    q: str = Query("", max_length=50),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retorna membros da academia cujo nome começa com q (autocomplete de @menções)."""
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    from sqlalchemy import func as _func
    from sqlalchemy import select as _select

    from app.models.user import User as _User

    stmt = _select(_User).where(_User.academy_id == academy_id).order_by(_User.name).limit(10)
    if q.strip():
        stmt = stmt.where(_func.lower(_User.name).like(f"%{q.lower()}%"))
    result = await db.execute(stmt)
    users = result.scalars().all()
    return [MentionSuggestion(id=u.id, name=u.name or "", avatar_url=u.avatar_url) for u in users]


# ---------------------------------------------------------------------------
# Comentários
# ---------------------------------------------------------------------------


@router.get("/{academy_id}/photos/{photo_id}/comments", response_model=list[CommentRead])
async def list_photo_comments(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id:
        raise NotFoundError("Post não encontrado.")

    comments = await list_comments(db, photo_id=photo_id)
    return [
        CommentRead(
            id=c.id,
            photo_id=c.photo_id,
            author=c.author,
            body=c.body,
            created_at=c.created_at,
        )
        for c in comments
    ]


@router.post("/{academy_id}/photos/{photo_id}/comments", response_model=CommentRead, status_code=201)
async def add_comment(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    body: CommentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id:
        raise NotFoundError("Post não encontrado.")

    comment = await create_comment(db, photo_id=photo_id, author_id=current_user.id, body=body.body)
    await db.commit()
    await db.refresh(comment)
    await invalidate_feed_cache(academy_id)

    # Notifica o dono da foto (se não for quem comentou)
    already_notified: set[uuid.UUID] = {current_user.id}
    if photo.author_id != current_user.id:
        already_notified.add(photo.author_id)
        await create_notification(
            db,
            user_id=photo.author_id,
            type="photo_comment",
            title=f"{current_user.name} comentou sua foto",
            body=body.body[:120],
            data={"photo_id": str(photo.id), "academy_id": str(academy_id), "comment_id": str(comment.id)},
        )

    # Notifica usuários @mencionados no comentário
    # 1) Novo formato @[Nome|uuid] — extrai UUIDs diretamente
    mention_ids: list[uuid.UUID] = [
        uid for uid in extract_mention_ids(body.body) if uid not in already_notified
    ]
    # 2) Formato legado @Palavra — resolve por nome (fallback)
    legacy_names = extract_mentions(body.body)
    if legacy_names:
        legacy_ids = await resolve_mention_user_ids(
            db, academy_id=academy_id, names=legacy_names, exclude_ids=already_notified
        )
        mention_ids.extend(uid for uid in legacy_ids if uid not in already_notified)
    for uid in mention_ids:
        already_notified.add(uid)
        await create_notification(
            db,
            user_id=uid,
            type="photo_mention",
            title=f"{current_user.name} te marcou em um comentário",
            body=body.body[:120],
            data={"photo_id": str(photo.id), "academy_id": str(academy_id), "comment_id": str(comment.id)},
        )

    return CommentRead(
        id=comment.id,
        photo_id=comment.photo_id,
        author=comment.author,
        body=comment.body,
        created_at=comment.created_at,
    )


@router.delete("/{academy_id}/photos/{photo_id}/comments/{comment_id}", status_code=204)
async def remove_comment(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)

    from sqlalchemy import select as _select

    from app.models.academy_photo import AcademyPhotoComment

    result = await db.execute(
        _select(AcademyPhotoComment).where(
            AcademyPhotoComment.id == comment_id,
            AcademyPhotoComment.deleted_at.is_(None),
        )
    )
    comment = result.scalar_one_or_none()
    if not comment or comment.photo_id != photo_id:
        raise NotFoundError("Comentário não encontrado.")

    is_author = comment.author_id == current_user.id
    if not is_author and not _is_moderator(current_user):
        raise ForbiddenError("Você não tem permissão para deletar este comentário.")

    await delete_comment(db, comment_id=comment_id)
    await db.commit()
    await invalidate_feed_cache(academy_id)
    return None


# ---------------------------------------------------------------------------
# Moderação — restrições (gerente/admin only)
# ---------------------------------------------------------------------------


@router.get("/{academy_id}/photos/restrictions", response_model=list[RestrictionRead])
async def list_photo_restrictions(
    academy_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a gerentes e administradores.")
    if current_user.role != "administrador" and str(current_user.academy_id) != str(academy_id):
        raise ForbiddenError("Acesso restrito à sua própria academia.")

    restrictions = await list_restrictions(db, academy_id=academy_id)
    return [
        RestrictionRead(
            id=r.id,
            academy_id=r.academy_id,
            user_id=r.user_id,
            user_name=r.restricted_user.name if r.restricted_user else None,
            reason=r.reason,
            expires_at=r.expires_at,
            active=r.active,
            created_at=r.created_at,
        )
        for r in restrictions
    ]


@router.post("/{academy_id}/photos/restrictions", response_model=RestrictionRead, status_code=201)
async def restrict_student(
    academy_id: uuid.UUID,
    body: RestrictionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a gerentes e administradores.")
    if current_user.role != "administrador" and str(current_user.academy_id) != str(academy_id):
        raise ForbiddenError("Acesso restrito à sua própria academia.")

    existing = await get_active_restriction(db, academy_id=academy_id, user_id=body.user_id)
    if existing:
        from app.core.exceptions import ConflictError

        raise ConflictError("Aluno já possui restrição ativa.")

    restriction = await create_restriction(
        db,
        academy_id=academy_id,
        user_id=body.user_id,
        restricted_by=current_user.id,
        reason=body.reason,
        expires_at=body.expires_at,
    )
    await db.commit()
    await db.refresh(restriction)
    return RestrictionRead(
        id=restriction.id,
        academy_id=restriction.academy_id,
        user_id=restriction.user_id,
        user_name=restriction.restricted_user.name if restriction.restricted_user else None,
        reason=restriction.reason,
        expires_at=restriction.expires_at,
        active=restriction.active,
        created_at=restriction.created_at,
    )


@router.patch("/{academy_id}/photos/restrictions/{restriction_id}", response_model=RestrictionRead)
async def update_restriction(
    academy_id: uuid.UUID,
    restriction_id: uuid.UUID,
    body: RestrictionPatch,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _require_octophotos(academy_id, db)
    if not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a gerentes e administradores.")

    restriction = await patch_restriction(
        db,
        restriction_id=restriction_id,
        active=body.active,
        reason=body.reason,
        expires_at=body.expires_at,
    )
    if not restriction or str(restriction.academy_id) != str(academy_id):
        raise NotFoundError("Restrição não encontrada.")
    await db.commit()
    await db.refresh(restriction)
    return RestrictionRead(
        id=restriction.id,
        academy_id=restriction.academy_id,
        user_id=restriction.user_id,
        user_name=restriction.restricted_user.name if restriction.restricted_user else None,
        reason=restriction.reason,
        expires_at=restriction.expires_at,
        active=restriction.active,
        created_at=restriction.created_at,
    )


# ---------------------------------------------------------------------------
# Post por ID — deve vir DEPOIS das rotas com segmentos fixos (/restrictions,
# /mention-suggestions) para o FastAPI não capturar "restrictions" como UUID.
# ---------------------------------------------------------------------------


@router.get("/{academy_id}/photos/{photo_id}", response_model=PhotoRead)
async def get_photo_by_id(
    academy_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retorna um post específico (usado para navegação por notificação)."""
    await _require_octophotos(academy_id, db)
    if not _is_academy_member(current_user, academy_id) and not _is_moderator(current_user):
        raise ForbiddenError("Acesso restrito a membros da academia.")

    photo = await get_academy_photo(db, photo_id)
    if not photo or photo.academy_id != academy_id:
        raise NotFoundError("Post não encontrado.")

    liked_ids = await get_liked_photo_ids(db, user_id=current_user.id, photo_ids=[photo.id])
    return _photo_to_read(photo, liked_ids)
