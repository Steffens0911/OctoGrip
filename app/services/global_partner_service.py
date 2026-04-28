"""Serviços CRUD para parceiros globais (admin global)."""
import logging
from uuid import UUID

from sqlalchemy import nulls_last, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache import app_cache
from app.models import GlobalPartner
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)

_FEATURED_GLOBAL_TTL_SEC = 600
_FEATURED_GLOBAL_PREFIX = "featured_global_partners:"

logger = logging.getLogger(__name__)

_ENTITY_GLOBAL_PARTNER = "GlobalPartner"


async def list_global_partners(db: AsyncSession) -> list[GlobalPartner]:
    stmt = select(GlobalPartner).order_by(
        GlobalPartner.is_active.desc(),
        nulls_last(GlobalPartner.featured_order.asc()),
        GlobalPartner.name.asc(),
    )
    return (await db.execute(stmt)).scalars().all()


async def list_active_global_featured(db: AsyncSession, *, limit: int = 5) -> list[GlobalPartner]:
    lim = max(1, min(limit, 50))
    cache_key = f"{_FEATURED_GLOBAL_PREFIX}active:{lim}"
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached
    stmt = (
        select(GlobalPartner)
        .where(GlobalPartner.is_active.is_(True))
        .order_by(nulls_last(GlobalPartner.featured_order.asc()))
        .limit(lim)
    )
    rows = (await db.execute(stmt)).scalars().all()
    await app_cache.set(cache_key, rows, ttl=_FEATURED_GLOBAL_TTL_SEC)
    return rows


async def get_global_partner(db: AsyncSession, partner_id: UUID) -> GlobalPartner | None:
    stmt = select(GlobalPartner).where(GlobalPartner.id == partner_id)
    return (await db.execute(stmt)).scalar_one_or_none()


async def create_global_partner(
    db: AsyncSession,
    *,
    name: str,
    description: str | None = None,
    logo_url: str | None = None,
    offer_text: str | None = None,
    external_url: str | None = None,
    button_label: str | None = None,
    featured_order: int | None = None,
    is_active: bool = True,
    audit_user_id: UUID | None = None,
) -> GlobalPartner:
    partner = GlobalPartner(
        name=name.strip(),
        description=description.strip() if description else None,
        logo_url=logo_url.strip() if logo_url else None,
        offer_text=offer_text.strip() if offer_text else None,
        external_url=external_url.strip() if external_url else None,
        button_label=button_label.strip() if button_label else None,
        featured_order=featured_order,
        is_active=is_active,
    )
    db.add(partner)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_GLOBAL_PARTNER,
        entity_id=partner.id,
        old_data=None,
        new_data=entity_snapshot_row(partner),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(partner)
    await app_cache.invalidate_prefix(_FEATURED_GLOBAL_PREFIX)
    logger.info("create_global_partner", extra={"global_partner_id": str(partner.id)})
    return partner


async def update_global_partner(
    db: AsyncSession,
    partner_id: UUID,
    *,
    name: str | None = None,
    description: str | None = None,
    logo_url: str | None = None,
    offer_text: str | None = None,
    external_url: str | None = None,
    button_label: str | None = None,
    featured_order: int | None = None,
    is_active: bool | None = None,
    audit_user_id: UUID | None = None,
) -> GlobalPartner | None:
    partner = await get_global_partner(db, partner_id)
    if not partner:
        return None
    before = entity_snapshot_row(partner)
    if name is not None:
        partner.name = name.strip()
    if description is not None:
        partner.description = description.strip() if description else None
    if logo_url is not None:
        partner.logo_url = logo_url.strip() if logo_url else None
    if offer_text is not None:
        partner.offer_text = offer_text.strip() if offer_text else None
    if external_url is not None:
        partner.external_url = external_url.strip() if external_url else None
    if button_label is not None:
        partner.button_label = button_label.strip() if button_label else None
    if featured_order is not None:
        partner.featured_order = featured_order
    if is_active is not None:
        partner.is_active = is_active
    await db.flush()
    await db.refresh(partner)
    after = entity_snapshot_row(partner)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_GLOBAL_PARTNER,
            entity_id=partner.id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(partner)
    await app_cache.invalidate_prefix(_FEATURED_GLOBAL_PREFIX)
    logger.info("update_global_partner", extra={"global_partner_id": str(partner.id)})
    return partner


async def delete_global_partner(
    db: AsyncSession,
    partner_id: UUID,
    *,
    audit_user_id: UUID | None = None,
) -> bool:
    partner = await get_global_partner(db, partner_id)
    if not partner:
        return False
    before = entity_snapshot_row(partner)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_GLOBAL_PARTNER,
        entity_id=partner.id,
        old_data=before,
        new_data=None,
        user_id=audit_user_id,
    )
    await db.delete(partner)
    await db.commit()
    await app_cache.invalidate_prefix(_FEATURED_GLOBAL_PREFIX)
    logger.info("delete_global_partner", extra={"global_partner_id": str(partner.id)})
    return True
