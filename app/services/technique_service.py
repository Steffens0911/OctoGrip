"""Serviços CRUD para Technique (sem dependência de Position)."""
import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache import techniques_cache
from app.core.exceptions import ConflictError
from app.core.slug import ensure_unique_slug, make_slug
from app.models import Lesson, Mission, Technique
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)

logger = logging.getLogger(__name__)

_ENTITY_TECHNIQUE = "Technique"


async def list_techniques(db: AsyncSession, academy_id: UUID | None = None, limit: int = 200) -> list[Technique]:
    """Lista técnicas ordenadas por nome. Se academy_id informado, filtra por academia."""
    stmt = select(Technique).where(Technique.deleted_at.is_(None))
    if academy_id is not None:
        stmt = stmt.where(Technique.academy_id == academy_id)
    return (await db.execute(stmt.order_by(Technique.name).limit(limit))).scalars().all()


async def get_technique(db: AsyncSession, technique_id: UUID) -> Technique | None:
    """Retorna uma técnica por ID (ignora soft-deletadas)."""
    return (
        await db.execute(
            select(Technique).where(
                Technique.id == technique_id,
                Technique.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()


async def create_technique(
    db: AsyncSession,
    academy_id: UUID,
    name: str,
    slug: str | None = None,
    description: str | None = None,
    video_url: str | None = None,
    base_points: int | None = None,
    audit_user_id: UUID | None = None,
) -> Technique:
    """Cria uma técnica na academia (sem posições de origem/destino)."""
    if not slug or not str(slug).strip():
        base = make_slug(name, fallback="tecnica")
        slug = await ensure_unique_slug(db, Technique, "slug", base, academy_id=academy_id)
    else:
        slug = slug.strip()
    technique = Technique(
        academy_id=academy_id,
        name=name.strip(),
        slug=slug,
        description=description.strip() if description else None,
        video_url=video_url.strip() if video_url and video_url.strip() else None,
        base_points=base_points,
    )
    db.add(technique)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_TECHNIQUE,
        entity_id=technique.id,
        old_data=None,
        new_data=entity_snapshot_row(technique),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(technique)
    await techniques_cache.invalidate_prefix(f"techniques:{academy_id}")
    logger.info("create_technique", extra={"technique_id": str(technique.id), "technique_name": technique.name})
    return technique


async def update_technique(
    db: AsyncSession,
    technique_id: UUID,
    name: str | None = None,
    slug: str | None = None,
    description: str | None = None,
    video_url: str | None = None,
    base_points: int | None = None,
    audit_user_id: UUID | None = None,
) -> Technique | None:
    """Atualiza uma técnica. Retorna None se não existir."""
    technique = await get_technique(db, technique_id)
    if not technique:
        return None
    before = entity_snapshot_row(technique)
    if name is not None:
        technique.name = name.strip()
    if slug is not None:
        technique.slug = slug.strip()
    if description is not None:
        technique.description = description.strip() if description else None
    if video_url is not None:
        technique.video_url = video_url.strip() if video_url and video_url.strip() else None
    if base_points is not None:
        technique.base_points = base_points
    after = entity_snapshot_row(technique)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_TECHNIQUE,
            entity_id=technique.id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(technique)
    await techniques_cache.invalidate_prefix(f"techniques:{technique.academy_id}")
    logger.info("update_technique", extra={"technique_id": str(technique_id)})
    return technique


async def delete_technique(
    db: AsyncSession, technique_id: UUID, audit_user_id: UUID | None = None
) -> bool:
    """Soft delete de uma técnica. Retorna True se marcou como removida."""
    technique = await get_technique(db, technique_id)
    if not technique:
        return False
    nm = await db.scalar(
        select(func.count())
        .select_from(Mission)
        .where(
            Mission.technique_id == technique_id,
            Mission.deleted_at.is_(None),
        )
    )
    nl = await db.scalar(
        select(func.count())
        .select_from(Lesson)
        .where(
            Lesson.technique_id == technique_id,
            Lesson.deleted_at.is_(None),
        )
    )
    if (nm or 0) + (nl or 0) > 0:
        raise ConflictError(
            "Não é possível excluir: existem lições ou missões vinculadas a esta técnica."
        )
    academy_id = technique.academy_id
    before = entity_snapshot_row(technique)
    now = datetime.now(timezone.utc)
    technique.deleted_at = now
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_TECHNIQUE,
        entity_id=technique.id,
        old_data=before,
        new_data={"deleted_at": now.isoformat()},
        user_id=audit_user_id,
    )
    await db.commit()
    await techniques_cache.invalidate_prefix(f"techniques:{academy_id}")
    logger.info("delete_technique", extra={"technique_id": str(technique_id)})
    return True
