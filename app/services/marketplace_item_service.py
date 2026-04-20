from __future__ import annotations

import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AcademyMarketplaceItem, User
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)

logger = logging.getLogger(__name__)

_ENTITY_MP = "AcademyMarketplaceItem"


async def list_marketplace_items_for_admin(
    db: AsyncSession,
    *,
    academy_id: UUID | None,
) -> list[AcademyMarketplaceItem]:
    stmt = select(AcademyMarketplaceItem)
    if academy_id is not None:
        stmt = stmt.where(AcademyMarketplaceItem.academy_id == academy_id)
    stmt = stmt.order_by(
        AcademyMarketplaceItem.sort_order.nulls_last(),
        AcademyMarketplaceItem.created_at.desc(),
    )
    return (await db.execute(stmt)).scalars().all()


async def list_active_marketplace_items_for_academy(
    db: AsyncSession,
    *,
    academy_id: UUID,
) -> list[AcademyMarketplaceItem]:
    stmt = (
        select(AcademyMarketplaceItem)
        .where(
            AcademyMarketplaceItem.academy_id == academy_id,
            AcademyMarketplaceItem.is_active.is_(True),
        )
        .order_by(
            AcademyMarketplaceItem.sort_order.nulls_last(),
            AcademyMarketplaceItem.created_at.desc(),
        )
    )
    return (await db.execute(stmt)).scalars().all()


async def get_marketplace_item(db: AsyncSession, item_id: UUID) -> AcademyMarketplaceItem | None:
    return (
        await db.execute(select(AcademyMarketplaceItem).where(AcademyMarketplaceItem.id == item_id))
    ).scalar_one_or_none()


async def create_marketplace_item(
    db: AsyncSession,
    *,
    academy_id: UUID,
    title: str,
    description: str | None,
    price_cents: int,
    currency: str,
    image_url: str | None,
    whatsapp_phone: str | None,
    sort_order: int | None,
    is_active: bool,
    created_by_id: UUID | None,
    audit_user_id: UUID | None = None,
) -> AcademyMarketplaceItem:
    row = AcademyMarketplaceItem(
        academy_id=academy_id,
        title=title.strip(),
        description=(description.strip() if description else None) or None,
        price_cents=price_cents,
        currency=currency.strip().upper()[:8],
        image_url=(image_url.strip() if image_url else None) or None,
        whatsapp_phone=whatsapp_phone,
        sort_order=sort_order,
        is_active=is_active,
        created_by_id=created_by_id,
    )
    db.add(row)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_MP,
        entity_id=row.id,
        old_data=None,
        new_data=entity_snapshot_row(row),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(row)
    logger.info("create_marketplace_item", extra={"item_id": str(row.id), "academy_id": str(academy_id)})
    return row


async def update_marketplace_item(
    db: AsyncSession,
    item_id: UUID,
    patch: dict,
    *,
    audit_user_id: UUID | None = None,
) -> AcademyMarketplaceItem | None:
    row = await get_marketplace_item(db, item_id)
    if not row:
        return None
    before = entity_snapshot_row(row)
    if "title" in patch and patch["title"] is not None:
        row.title = str(patch["title"]).strip()
    if "description" in patch:
        d = patch["description"]
        row.description = (d.strip() if isinstance(d, str) and d.strip() else None) if d is not None else None
    if "price_cents" in patch and patch["price_cents"] is not None:
        row.price_cents = int(patch["price_cents"])
    if "currency" in patch and patch["currency"] is not None:
        row.currency = str(patch["currency"]).strip().upper()[:8]
    if "image_url" in patch:
        iu = patch["image_url"]
        row.image_url = iu.strip() if isinstance(iu, str) and iu.strip() else None
    if "whatsapp_phone" in patch:
        row.whatsapp_phone = patch["whatsapp_phone"]
    if "sort_order" in patch:
        row.sort_order = patch["sort_order"]
    if "is_active" in patch and patch["is_active"] is not None:
        row.is_active = bool(patch["is_active"])
    await db.flush()
    await db.refresh(row)
    after = entity_snapshot_row(row)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_MP,
            entity_id=item_id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(row)
    logger.info("update_marketplace_item", extra={"item_id": str(row.id)})
    return row


async def delete_marketplace_item(
    db: AsyncSession,
    item_id: UUID,
    *,
    audit_user_id: UUID | None = None,
) -> bool:
    row = await get_marketplace_item(db, item_id)
    if not row:
        return False
    before = entity_snapshot_row(row)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_MP,
        entity_id=item_id,
        old_data=before,
        new_data=None,
        user_id=audit_user_id,
    )
    await db.delete(row)
    await db.commit()
    logger.info("delete_marketplace_item", extra={"item_id": str(item_id)})
    return True


async def list_marketplace_items_for_user(db: AsyncSession, *, user: User) -> list[AcademyMarketplaceItem]:
    """Itens ativos da academia do aluno (ou lista vazia se sem academia)."""
    if user.academy_id is None:
        return []
    return await list_active_marketplace_items_for_academy(db, academy_id=user.academy_id)
