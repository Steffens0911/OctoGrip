"""Geração de slug a partir de texto e garantia de unicidade."""
import re
from typing import TypeVar
from uuid import UUID

from sqlalchemy.orm import Session

M = TypeVar("M")


def make_slug(text: str, fallback: str = "item") -> str:
    """Gera slug: minúsculas, apenas a-z 0-9, separados por hífen."""
    if not text or not str(text).strip():
        return fallback
    slug = re.sub(r"[^a-z0-9]+", "-", str(text).lower().strip()).strip("-")
    return slug or fallback


def ensure_unique_slug(
    db: Session,
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
        q = db.query(model_class).filter(getattr(model_class, slug_attr) == slug)
        if academy_id is not None:
            q = q.filter(getattr(model_class, academy_attr) == academy_id)
        if q.first() is None:
            break
        slug = f"{base_slug}-{n}"
        n += 1
    return slug
