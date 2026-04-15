"""CRUD de turmas semanais (1–5 técnicas por turma) por academia (professor/gerente/admin).

Na UI o produto chama **turma**; as rotas mantêm o segmento ``/weekly-kits`` (e alias ``/weekly_kits``).
"""
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.cache import app_cache
from app.core.exceptions import AppError, NotFoundError
from app.core.role_deps import require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.weekly_kit import (
    WeeklyKitCreate,
    WeeklyKitItemRead,
    WeeklyKitRead,
    WeeklyKitUpdate,
)
from app.services.weekly_kit_service import (
    create_kit,
    get_kit,
    list_active_kits_for_academy,
    replace_kit_items_and_sync_missions,
    soft_delete_kit,
    update_kit_meta,
)

router = APIRouter()


def _kit_to_read(kit) -> WeeklyKitRead:
    items_sorted = sorted(kit.items or [], key=lambda x: x.order_index)
    items = [
        WeeklyKitItemRead(
            order_index=it.order_index,
            technique_id=it.technique_id,
            technique_name=it.technique.name if getattr(it, "technique", None) else None,
            multiplier=it.multiplier,
        )
        for it in items_sorted
    ]
    return WeeklyKitRead(
        id=kit.id,
        academy_id=kit.academy_id,
        label=kit.label,
        sort_order=kit.sort_order,
        items=items,
    )


@router.get(
    "/{academy_id}/weekly_kits",
    response_model=list[WeeklyKitRead],
    include_in_schema=False,
    operation_id="list_weekly_kits_path_underscore",
)
@router.get("/{academy_id}/weekly-kits", response_model=list[WeeklyKitRead])
async def list_weekly_kits(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_academy_access(current_user, str(academy_id))
    kits = await list_active_kits_for_academy(db, academy_id)
    return [_kit_to_read(k) for k in kits]


@router.post(
    "/{academy_id}/weekly_kits",
    response_model=WeeklyKitRead,
    status_code=201,
    include_in_schema=False,
    operation_id="create_weekly_kit_path_underscore",
)
@router.post("/{academy_id}/weekly-kits", response_model=WeeklyKitRead, status_code=201)
async def create_weekly_kit(
    academy_id: UUID,
    body: WeeklyKitCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    verify_academy_access(current_user, str(academy_id))
    kit = await create_kit(db, academy_id, label=body.label, sort_order=body.sort_order)
    if body.items:
        if len(body.items) < 1 or len(body.items) > 5:
            raise AppError("Cada kit deve ter entre 1 e 5 técnicas.", status_code=400)
        tuples = [(x.technique_id, x.multiplier) for x in body.items]
        kit = await replace_kit_items_and_sync_missions(db, kit.id, academy_id, tuples)
    k2 = await get_kit(db, kit.id, academy_id)
    if not k2:
        raise NotFoundError("Kit não encontrado.")
    await app_cache.invalidate_prefix("mission_week:")
    return _kit_to_read(k2)


@router.patch(
    "/{academy_id}/weekly_kits/{kit_id}",
    response_model=WeeklyKitRead,
    include_in_schema=False,
    operation_id="patch_weekly_kit_path_underscore",
)
@router.patch("/{academy_id}/weekly-kits/{kit_id}", response_model=WeeklyKitRead)
async def patch_weekly_kit(
    academy_id: UUID,
    kit_id: UUID,
    body: WeeklyKitUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    verify_academy_access(current_user, str(academy_id))
    if body.label is not None or body.sort_order is not None:
        await update_kit_meta(
            db,
            kit_id,
            academy_id,
            label=body.label,
            sort_order=body.sort_order,
        )
    if body.items is not None:
        if len(body.items) < 1 or len(body.items) > 5:
            raise AppError("Cada kit deve ter entre 1 e 5 técnicas.", status_code=400)
        tuples = [(x.technique_id, x.multiplier) for x in body.items]
        await replace_kit_items_and_sync_missions(db, kit_id, academy_id, tuples)
    k = await get_kit(db, kit_id, academy_id)
    if not k:
        raise NotFoundError("Kit não encontrado.")
    await app_cache.invalidate_prefix("mission_week:")
    return _kit_to_read(k)


@router.delete(
    "/{academy_id}/weekly_kits/{kit_id}",
    status_code=204,
    include_in_schema=False,
    operation_id="delete_weekly_kit_path_underscore",
)
@router.delete("/{academy_id}/weekly-kits/{kit_id}", status_code=204)
async def delete_weekly_kit(
    academy_id: UUID,
    kit_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    verify_academy_access(current_user, str(academy_id))
    ok = await soft_delete_kit(db, kit_id, academy_id)
    if not ok:
        raise NotFoundError("Kit não encontrado.")
    await app_cache.invalidate_prefix("mission_week:")
    return None
