from __future__ import annotations

import io
import logging
import uuid as _uuid_mod
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, File, Query, UploadFile
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.exceptions import AppError, ForbiddenError
from app.core.list_pagination import MAX_LIST_LIMIT
from app.core.role_deps import require_write_access
from app.database import AsyncSessionLocal, get_db
from app.models import User
from app.schemas.marketplace_item import (
    MarketplaceItemAdminRead,
    MarketplaceItemCreate,
    MarketplaceItemUpdate,
    marketplace_item_admin_read_from_orm,
)
from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
from app.services.marketplace_item_service import (
    create_marketplace_item,
    delete_marketplace_item,
    get_marketplace_item,
    list_marketplace_items_for_admin,
    update_marketplace_item,
)
from app.services.notification_service import create_notifications_for_academy_students
from app.services.push_token_service import delete_device_token, list_fcm_tokens_for_academy
from app.utils.marketplace_whatsapp import normalize_br_whatsapp_phone

logger = logging.getLogger(__name__)

router = APIRouter()

_MEDIA_ROOT = (Path(__file__).resolve().parent.parent.parent / "app_media").resolve()
_MARKETPLACE_DIR = _MEDIA_ROOT / "marketplace"
_MAX_UPLOAD_MB = 10
_MAX_IMAGE_PX = 1200
_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _merge_whatsapp_into_patch(patch: dict) -> None:
    """Se DDD/número vierem no PATCH, normaliza para `whatsapp_phone` e remove chaves originais."""
    if "whatsapp_ddd" not in patch and "whatsapp_number" not in patch:
        return
    ddd = patch.pop("whatsapp_ddd", None)
    num = patch.pop("whatsapp_number", None)
    try:
        patch["whatsapp_phone"] = normalize_br_whatsapp_phone(ddd, num)
    except ValueError as e:
        raise AppError(str(e), status_code=400) from e


async def _send_new_item_push(academy_id: UUID, item_title: str) -> None:
    """Dispara push para todos os alunos da academia ao publicar anúncio novo."""
    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        return
    try:
        async with AsyncSessionLocal() as db:
            tokens = await list_fcm_tokens_for_academy(db, academy_id=academy_id)
            if not tokens:
                return
            try:
                access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
            except Exception:
                logger.warning("marketplace push: falha ao obter token FCM")
                return
            sent = 0
            for device_token in tokens:
                try:
                    ok, drop = await send_fcm_data_message(
                        project_id=settings.FIREBASE_PROJECT_ID,
                        service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
                        device_token=device_token,
                        title="Novo produto na loja",
                        body=item_title,
                        access_token=access_token,
                        data={"type": "marketplace_new_item"},
                    )
                except Exception:
                    continue
                if ok:
                    sent += 1
                elif drop:
                    try:
                        await delete_device_token(db, fcm_token=device_token)
                    except Exception:
                        pass
            if sent > 0:
                await create_notifications_for_academy_students(
                    db,
                    academy_id=academy_id,
                    type="academy_push",
                    title="Novo produto na loja",
                    body=item_title,
                    roles=("aluno", "professor", "gerente_academia", "supervisor"),
                )
    except Exception:
        logger.exception("marketplace push: erro inesperado")


@router.post("/upload_image")
async def marketplace_upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(require_write_access),
):
    """
    Faz upload de imagem para um anúncio do marketplace.
    Retorna `{"image_url": "/media/marketplace/{uuid}.jpg"}`.
    """
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise AppError(
            f"Tipo de arquivo inválido. Permitidos: {', '.join(_ALLOWED_CONTENT_TYPES)}.",
            status_code=400,
        )
    raw = await file.read()
    if len(raw) > _MAX_UPLOAD_MB * 1024 * 1024:
        raise AppError(f"Arquivo muito grande. Limite: {_MAX_UPLOAD_MB} MB.", status_code=413)
    try:
        img = Image.open(io.BytesIO(raw)).convert("RGB")
        img.thumbnail((_MAX_IMAGE_PX, _MAX_IMAGE_PX), Image.LANCZOS)
        _MARKETPLACE_DIR.mkdir(parents=True, exist_ok=True)
        filename = f"{_uuid_mod.uuid4()}.jpg"
        dest = _MARKETPLACE_DIR / filename
        img.save(str(dest), format="JPEG", quality=85, optimize=True)
    except Exception as exc:
        raise AppError("Não foi possível processar a imagem.", status_code=400) from exc
    return {"image_url": f"/media/marketplace/{filename}"}


@router.get("", response_model=list[MarketplaceItemAdminRead])
async def marketplace_items_list(
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT, description="Limite de resultados (máximo 50)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Lista anúncios do marketplace (admin: todos; gerente/professor: só da sua academia)."""
    academy_filter: UUID | None = None
    if current_user.role != "administrador":
        if current_user.academy_id is None:
            return []
        academy_filter = current_user.academy_id
    rows = await list_marketplace_items_for_admin(
        db,
        academy_id=academy_filter,
        limit=limit,
        offset=offset,
    )
    return [marketplace_item_admin_read_from_orm(r) for r in rows]


@router.post("", response_model=MarketplaceItemAdminRead, status_code=201)
async def marketplace_item_create(
    body: MarketplaceItemCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    if current_user.role == "administrador":
        if body.academy_id is None:
            raise AppError("Administrador deve informar academy_id ao criar anúncio.", status_code=400)
        academy_id = body.academy_id
    else:
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia para criar anúncios.")
        academy_id = current_user.academy_id
    try:
        phone = normalize_br_whatsapp_phone(body.whatsapp_ddd, body.whatsapp_number)
    except ValueError as e:
        raise AppError(str(e), status_code=400) from e
    row = await create_marketplace_item(
        db,
        academy_id=academy_id,
        title=body.title,
        description=body.description,
        price_cents=body.price_cents,
        currency=body.currency,
        image_url=body.image_url,
        whatsapp_phone=phone,
        sort_order=body.sort_order,
        is_active=body.is_active,
        created_by_id=current_user.id,
        audit_user_id=current_user.id,
    )
    if row.is_active:
        background_tasks.add_task(_send_new_item_push, academy_id, row.title)
    return marketplace_item_admin_read_from_orm(row)


@router.put("/{item_id}", response_model=MarketplaceItemAdminRead)
async def marketplace_item_update(
    item_id: UUID,
    body: MarketplaceItemUpdate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    from app.core.exceptions import NotFoundError

    row = await get_marketplace_item(db, item_id)
    if not row:
        raise NotFoundError("Anúncio não encontrado.")
    if current_user.role != "administrador":
        if current_user.academy_id is None or row.academy_id != current_user.academy_id:
            raise ForbiddenError("Você não tem permissão para editar este anúncio.")
    was_inactive = not row.is_active
    patch = body.model_dump(exclude_unset=True)
    _merge_whatsapp_into_patch(patch)
    updated = await update_marketplace_item(db, item_id, patch, audit_user_id=current_user.id)
    assert updated is not None
    # Dispara push somente quando o anúncio passa de inativo → ativo
    if was_inactive and updated.is_active:
        background_tasks.add_task(_send_new_item_push, updated.academy_id, updated.title)
    return marketplace_item_admin_read_from_orm(updated)


@router.delete("/{item_id}", status_code=204)
async def marketplace_item_delete(
    item_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    from app.core.exceptions import NotFoundError

    row = await get_marketplace_item(db, item_id)
    if not row:
        raise NotFoundError("Anúncio não encontrado.")
    if current_user.role != "administrador":
        if current_user.academy_id is None or row.academy_id != current_user.academy_id:
            raise ForbiddenError("Você não tem permissão para remover este anúncio.")
    ok = await delete_marketplace_item(db, item_id, audit_user_id=current_user.id)
    if not ok:
        raise NotFoundError("Anúncio não encontrado.")
    return None
