"""Tasks Celery para OctoPhotos: resize/thumbnail e expiração de restrições."""

from __future__ import annotations

import os
import uuid
from pathlib import Path

from celery.utils.log import get_task_logger
from PIL import Image

from app.database import SyncSessionLocal
from celery_app import celery_app

logger = get_task_logger(__name__)

_BASE_DIR = Path(__file__).resolve().parent.parent.parent
_MEDIA_ROOT = (_BASE_DIR / "app_media").resolve()
_PHOTOS_DIR = _MEDIA_ROOT / "photos"

_MAX_FULL_SIDE = 1080
_THUMB_W, _THUMB_H = 400, 300


def _ensure_photos_dir() -> Path:
    _PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
    return _PHOTOS_DIR


def _resize_image(src_path: str, photo_id: str) -> tuple[str, str]:
    """Redimensiona e gera thumbnail. Retorna (image_url_path, thumbnail_url_path)."""
    photos_dir = _ensure_photos_dir()
    full_name = f"{photo_id}_full.jpg"
    thumb_name = f"{photo_id}_thumb.jpg"
    full_path = photos_dir / full_name
    thumb_path = photos_dir / thumb_name

    with Image.open(src_path) as img:
        img = img.convert("RGB")
        w, h = img.size
        longest = max(w, h)
        if longest > _MAX_FULL_SIDE:
            scale = _MAX_FULL_SIDE / longest
            img = img.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
        img.save(str(full_path), "JPEG", quality=85, optimize=True)

    with Image.open(src_path) as img:
        img = img.convert("RGB")
        img.thumbnail((_THUMB_W * 4, _THUMB_H * 4), Image.LANCZOS)
        # Crop centralizado para 400×300
        w, h = img.size
        ratio_w, ratio_h = _THUMB_W / w, _THUMB_H / h
        scale = max(ratio_w, ratio_h)
        new_w, new_h = max(1, int(w * scale)), max(1, int(h * scale))
        img = img.resize((new_w, new_h), Image.LANCZOS)
        left = (new_w - _THUMB_W) // 2
        top = (new_h - _THUMB_H) // 2
        img = img.crop((left, top, left + _THUMB_W, top + _THUMB_H))
        img.save(str(thumb_path), "JPEG", quality=75, optimize=True)

    return f"/media/photos/{full_name}", f"/media/photos/{thumb_name}"


@celery_app.task(bind=True, max_retries=3, default_retry_delay=30)
def process_photo_upload(self, photo_id: str, raw_file_path: str) -> None:
    """Redimensiona upload bruto, salva full e thumbnail, atualiza BD."""
    from sqlalchemy import select, update

    from app.models.academy_photo import AcademyPhoto

    try:
        image_path, thumbnail_path = _resize_image(raw_file_path, photo_id)
    except Exception as exc:
        logger.exception("Erro ao processar imagem photo_id=%s: %s", photo_id, exc)
        with SyncSessionLocal() as db:
            db.execute(update(AcademyPhoto).where(AcademyPhoto.id == uuid.UUID(photo_id)).values(status="failed"))
            db.commit()
        raise self.retry(exc=exc)

    academy_id_str: str | None = None
    with SyncSessionLocal() as db:
        # Obtém academy_id antes do UPDATE (fetchone pós-commit fecha o cursor)
        photo_row = db.execute(select(AcademyPhoto.academy_id).where(AcademyPhoto.id == uuid.UUID(photo_id))).fetchone()
        if photo_row:
            academy_id_str = str(photo_row[0])

        db.execute(
            update(AcademyPhoto)
            .where(AcademyPhoto.id == uuid.UUID(photo_id))
            .values(
                image_url=image_path,
                thumbnail_url=thumbnail_path,
                status="ready",
                raw_file_path=None,
            )
        )
        db.commit()

    # Invalida cache do feed para que o post apareça com status "ready" imediatamente.
    if academy_id_str:
        try:
            from redis import Redis as SyncRedis

            from app.config import settings

            r = SyncRedis.from_url(settings.REDIS_URL, decode_responses=True)
            pv_key = f"app_cache:__pv__:photos:feed:{academy_id_str}:"
            r.incr(pv_key)
            r.close()
        except Exception as exc:
            logger.warning("Falha ao invalidar cache do feed photo_id=%s: %s", photo_id, exc)

    # Remove arquivo bruto após processamento bem-sucedido
    try:
        if raw_file_path and os.path.exists(raw_file_path):
            os.remove(raw_file_path)
    except OSError:
        logger.warning("Não foi possível remover arquivo bruto: %s", raw_file_path)

    logger.info("photo_id=%s processada com sucesso", photo_id)


@celery_app.task
def expire_photo_restrictions() -> None:
    """Desativa restrições com expires_at no passado (rodar periodicamente via beat)."""
    from datetime import UTC, datetime

    from sqlalchemy import update

    from app.models.academy_photo import AcademyPhotoRestriction

    now = datetime.now(UTC)
    with SyncSessionLocal() as db:
        result = db.execute(
            update(AcademyPhotoRestriction)
            .where(
                AcademyPhotoRestriction.active.is_(True),
                AcademyPhotoRestriction.expires_at.is_not(None),
                AcademyPhotoRestriction.expires_at <= now,
            )
            .values(active=False)
        )
        db.commit()
        logger.info("Restrições expiradas desativadas: %d", result.rowcount)
