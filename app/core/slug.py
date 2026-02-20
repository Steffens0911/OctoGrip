"""Geração de slug a partir de texto e garantia de unicidade."""
import re
from typing import TypeVar
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

M = TypeVar("M")


def make_slug(text: str, fallback: str = "item") -> str:
    """Gera slug: minúsculas, apenas a-z 0-9, separados por hífen."""
    if not text or not str(text).strip():
        return fallback
    slug = re.sub(r"[^a-z0-9]+", "-", str(text).lower().strip()).strip("-")
    return slug or fallback


async def ensure_unique_slug(
    db: AsyncSession,
    model_class: type[M],
    slug_attr: str,
    base_slug: str,
    academy_id: UUID | None = None,
    academy_attr: str = "academy_id",
) -> str:
    """Retorna base_slug ou base_slug-2, base_slug-3, ... até ser único.
    Se academy_id informado, unicidade é por (academy_id, slug); senão por slug apenas."""
    slug = base_slug
    n = 2
    while True:
        stmt = select(model_class).where(getattr(model_class, slug_attr) == slug)
        if academy_id is not None:
            stmt = stmt.where(getattr(model_class, academy_attr) == academy_id)
        result = (await db.execute(stmt)).scalar_one_or_none()
        if result is None:
            break
        slug = f"{base_slug}-{n}"
        n += 1
    return slug
