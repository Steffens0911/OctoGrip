"""Serviços CRUD para Partner."""

import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.list_pagination import clamp_list_limit
from app.models import Partner
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)

logger = logging.getLogger(__name__)

_ENTITY_PARTNER = "Partner"


async def list_partners(
    db: AsyncSession,
    academy_id: UUID,
    *,
    limit: int = 50,
    offset: int = 0,
    search: str | None = None,
) -> list[Partner]:
    """Lista parceiros da academia ordenados por nome."""
    safe_limit = clamp_list_limit(limit)
    safe_offset = max(0, int(offset))
    stmt = select(Partner).where(Partner.academy_id == academy_id)
    if search:
        stmt = stmt.where(Partner.name.ilike(f"%{search.strip()}%"))
    stmt = stmt.order_by(Partner.name).offset(safe_offset).limit(safe_limit)
    return (await db.execute(stmt)).scalars().all()


async def get_partner(db: AsyncSession, partner_id: UUID) -> Partner | None:
    """Retorna um parceiro por ID."""
    return (await db.execute(select(Partner).where(Partner.id == partner_id))).scalar_one_or_none()


async def create_partner(
    db: AsyncSession,
    academy_id: UUID,
    name: str,
    description: str | None = None,
    url: str | None = None,
    logo_url: str | None = None,
    button_label: str | None = None,
    highlight_on_login: bool = False,
    *,
    audit_user_id: UUID | None = None,
) -> Partner:
    """Cria um parceiro na academia."""
    partner = Partner(
        academy_id=academy_id,
        name=name.strip(),
        description=description.strip() if description else None,
        url=url.strip() if url else None,
        logo_url=logo_url.strip() if logo_url else None,
        button_label=button_label.strip() if button_label else None,
        highlight_on_login=highlight_on_login,
    )
    db.add(partner)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_PARTNER,
        entity_id=partner.id,
        old_data=None,
        new_data=entity_snapshot_row(partner),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(partner)
    logger.info("create_partner", extra={"partner_id": str(partner.id), "partner_name": partner.name})
    return partner


async def update_partner(
    db: AsyncSession,
    partner_id: UUID,
    name: str | None = None,
    description: str | None = None,
    url: str | None = None,
    logo_url: str | None = None,
    button_label: str | None = None,
    highlight_on_login: bool | None = None,
    *,
    audit_user_id: UUID | None = None,
) -> Partner | None:
    """Atualiza um parceiro. Retorna None se não existir."""
    partner = await get_partner(db, partner_id)
    if not partner:
        return None
    before = entity_snapshot_row(partner)
    if name is not None:
        partner.name = name.strip()
    if description is not None:
        partner.description = description.strip() if description else None
    if url is not None:
        partner.url = url.strip() if url else None
    if logo_url is not None:
        partner.logo_url = logo_url.strip() if logo_url else None
    if button_label is not None:
        partner.button_label = button_label.strip() if button_label else None
    if highlight_on_login is not None:
        partner.highlight_on_login = highlight_on_login
    await db.flush()
    await db.refresh(partner)
    after = entity_snapshot_row(partner)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_PARTNER,
            entity_id=partner_id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(partner)
    logger.info("update_partner", extra={"partner_id": str(partner_id)})
    return partner


async def delete_partner(
    db: AsyncSession,
    partner_id: UUID,
    *,
    audit_user_id: UUID | None = None,
) -> bool:
    """Remove um parceiro. Retorna True se removeu, False se não existir."""
    partner = await get_partner(db, partner_id)
    if not partner:
        return False
    before = entity_snapshot_row(partner)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_PARTNER,
        entity_id=partner_id,
        old_data=before,
        new_data=None,
        user_id=audit_user_id,
    )
    await db.delete(partner)
    await db.commit()
    logger.info("delete_partner", extra={"partner_id": str(partner_id)})
    return True
