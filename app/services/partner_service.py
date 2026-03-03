"""Serviços CRUD para Partner."""
import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Partner

logger = logging.getLogger(__name__)


async def list_partners(db: AsyncSession, academy_id: UUID) -> list[Partner]:
    """Lista parceiros da academia ordenados por nome."""
    stmt = (
        select(Partner)
        .where(Partner.academy_id == academy_id)
        .order_by(Partner.name)
    )
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
    highlight_on_login: bool = False,
) -> Partner:
    """Cria um parceiro na academia."""
    partner = Partner(
        academy_id=academy_id,
        name=name.strip(),
        description=description.strip() if description else None,
        url=url.strip() if url else None,
        logo_url=logo_url.strip() if logo_url else None,
        highlight_on_login=highlight_on_login,
    )
    db.add(partner)
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
    highlight_on_login: bool | None = None,
) -> Partner | None:
    """Atualiza um parceiro. Retorna None se não existir."""
    partner = await get_partner(db, partner_id)
    if not partner:
        return None
    if name is not None:
        partner.name = name.strip()
    if description is not None:
        partner.description = description.strip() if description else None
    if url is not None:
        partner.url = url.strip() if url else None
    if logo_url is not None:
        partner.logo_url = logo_url.strip() if logo_url else None
    if highlight_on_login is not None:
        partner.highlight_on_login = highlight_on_login
    await db.commit()
    await db.refresh(partner)
    logger.info("update_partner", extra={"partner_id": str(partner_id)})
    return partner


async def delete_partner(db: AsyncSession, partner_id: UUID) -> bool:
    """Remove um parceiro. Retorna True se removeu, False se não existir."""
    partner = await get_partner(db, partner_id)
    if not partner:
        return False
    await db.delete(partner)
    await db.commit()
    logger.info("delete_partner", extra={"partner_id": str(partner_id)})
    return True
