import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import LessonNotFoundError, TechniqueNotFoundError
from app.core.slug import ensure_unique_slug, make_slug
from app.models import Lesson, Technique
from app.schemas.lesson import LessonCreate, LessonUpdate
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)

logger = logging.getLogger(__name__)

_ENTITY_LESSON = "Lesson"


async def list_lessons(
    db: AsyncSession,
    academy_id: UUID | None = None,
    offset: int = 0,
    limit: int = 100,
):
    """
    Lista aulas ordenadas por order_index com paginação.
    Se academy_id for informado e a academia tiver visible_lesson_id, retorna apenas essa lição.
    Senão retorna todas com paginação (default: 100 por página).
    """
    from app.models import Academy

    if academy_id:
        academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
        if academy and academy.visible_lesson_id:
            lesson = (
                await db.execute(
            select(Lesson)
            .options(
                selectinload(Lesson.technique),
            )
            .where(
                Lesson.id == academy.visible_lesson_id,
                Lesson.deleted_at.is_(None),
            )
                )
            ).unique().scalars().first()
            if lesson:
                logger.debug("list_lessons", extra={"academy_id": str(academy_id), "count": 1})
                return [lesson]
    
    # Aplicar paginação
    limit = min(max(1, limit), 500)  # Máximo 500 por página
    offset = max(0, offset)
    
    lessons = (
        await db.execute(
            select(Lesson)
            .options(
                selectinload(Lesson.technique),
            )
            .where(Lesson.deleted_at.is_(None))
            .order_by(Lesson.order_index.asc())
            .offset(offset)
            .limit(limit)
        )
    ).unique().scalars().all()
    logger.debug("list_lessons", extra={"count": len(lessons), "offset": offset, "limit": limit})
    return lessons


async def get_lesson_by_id(db: AsyncSession, lesson_id: UUID) -> Lesson:
    """Retorna uma aula por ID. Levanta LessonNotFoundError se não existir."""
    lesson = (
        await db.execute(
            select(Lesson)
            .options(
                selectinload(Lesson.technique),
            )
            .where(Lesson.id == lesson_id, Lesson.deleted_at.is_(None))
        )
    ).unique().scalars().first()
    if not lesson:
        logger.info("get_lesson_by_id not_found", extra={"lesson_id": str(lesson_id)})
        raise LessonNotFoundError("Lição não encontrada.")
    return lesson


async def create_lesson(
    db: AsyncSession, data: LessonCreate, audit_user_id: UUID | None = None
) -> Lesson:
    """Cria uma aula. Slug gerado automaticamente a partir do título se omitido."""
    technique = (
        await db.execute(
            select(Technique).where(
                Technique.id == data.technique_id,
                Technique.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if not technique:
        logger.info("create_lesson technique_not_found", extra={"technique_id": str(data.technique_id)})
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if not data.slug or not str(data.slug).strip():
        base = make_slug(data.title, fallback="licao")
        slug = await ensure_unique_slug(db, Lesson, "slug", base)
    else:
        slug = data.slug.strip()
    lesson = Lesson(
        academy_id=technique.academy_id,
        technique_id=data.technique_id,
        title=data.title,
        slug=slug,
        video_url=data.video_url,
        content=data.content,
        order_index=data.order_index,
        base_points=data.base_points,
    )
    db.add(lesson)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_LESSON,
        entity_id=lesson.id,
        old_data=None,
        new_data=entity_snapshot_row(lesson),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(lesson)
    logger.info("create_lesson", extra={"lesson_id": str(lesson.id), "title": lesson.title})
    return lesson


async def update_lesson(
    db: AsyncSession,
    lesson_id: UUID,
    data: LessonUpdate,
    audit_user_id: UUID | None = None,
) -> Lesson:
    """Atualiza uma aula (apenas campos enviados). Levanta LessonNotFoundError ou TechniqueNotFoundError."""
    lesson = await get_lesson_by_id(db, lesson_id)
    before = entity_snapshot_row(lesson)
    payload = data.model_dump(exclude_unset=True)
    if "technique_id" in payload:
        tech = (
            await db.execute(
                select(Technique).where(
                    Technique.id == payload["technique_id"],
                    Technique.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if not tech:
            logger.info("update_lesson technique_not_found", extra={"technique_id": str(payload["technique_id"])})
            raise TechniqueNotFoundError("Técnica não encontrada.")
        lesson.technique_id = payload["technique_id"]
        lesson.academy_id = tech.academy_id
    for key in ("title", "slug", "video_url", "content", "order_index", "base_points"):
        if key in payload:
            setattr(lesson, key, payload[key])
    after = entity_snapshot_row(lesson)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_LESSON,
            entity_id=lesson.id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(lesson)
    logger.info("update_lesson", extra={"lesson_id": str(lesson_id)})
    return lesson


async def delete_lesson(
    db: AsyncSession, lesson_id: UUID, audit_user_id: UUID | None = None
) -> None:
    """Soft delete de uma aula. Levanta LessonNotFoundError se não existir."""
    lesson = await get_lesson_by_id(db, lesson_id)
    before = entity_snapshot_row(lesson)
    now = datetime.now(timezone.utc)
    lesson.deleted_at = now
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_LESSON,
        entity_id=lesson.id,
        old_data=before,
        new_data={"deleted_at": now.isoformat()},
        user_id=audit_user_id,
    )
    await db.commit()
    logger.info("delete_lesson", extra={"lesson_id": str(lesson_id)})
