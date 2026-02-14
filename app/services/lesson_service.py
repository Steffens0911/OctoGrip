import logging
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import LessonNotFoundError, TechniqueNotFoundError
from app.core.slug import ensure_unique_slug, make_slug
from app.models import Lesson, Technique
from app.schemas.lesson import LessonCreate, LessonUpdate

logger = logging.getLogger(__name__)


def list_lessons(db: Session):
    """Lista todas as aulas ordenadas por order_index, com técnica e posições."""
    lessons = (
        db.query(Lesson)
        .options(
            joinedload(Lesson.technique).joinedload(Technique.from_position),
            joinedload(Lesson.technique).joinedload(Technique.to_position),
        )
        .order_by(Lesson.order_index.asc())
        .all()
    )
    logger.debug("list_lessons", extra={"count": len(lessons)})
    return lessons


def get_lesson_by_id(db: Session, lesson_id: UUID) -> Lesson:
    """Retorna uma aula por ID. Levanta LessonNotFoundError se não existir."""
    lesson = (
        db.query(Lesson)
        .options(
            joinedload(Lesson.technique).joinedload(Technique.from_position),
            joinedload(Lesson.technique).joinedload(Technique.to_position),
        )
        .filter(Lesson.id == lesson_id)
        .first()
    )
    if not lesson:
        logger.info("get_lesson_by_id not_found", extra={"lesson_id": str(lesson_id)})
        raise LessonNotFoundError("Lição não encontrada.")
    return lesson


def create_lesson(db: Session, data: LessonCreate) -> Lesson:
    """Cria uma aula. Slug gerado automaticamente a partir do título se omitido."""
    technique = db.query(Technique).filter(Technique.id == data.technique_id).first()
    if not technique:
        logger.info("create_lesson technique_not_found", extra={"technique_id": str(data.technique_id)})
        raise TechniqueNotFoundError("Técnica não encontrada.")
    if not data.slug or not str(data.slug).strip():
        base = make_slug(data.title, fallback="licao")
        slug = ensure_unique_slug(db, Lesson, "slug", base)
    else:
        slug = data.slug.strip()
    lesson = Lesson(
        technique_id=data.technique_id,
        title=data.title,
        slug=slug,
        video_url=data.video_url,
        content=data.content,
        order_index=data.order_index,
    )
    db.add(lesson)
    db.commit()
    db.refresh(lesson)
    logger.info("create_lesson", extra={"lesson_id": str(lesson.id), "title": lesson.title})
    return lesson


def update_lesson(db: Session, lesson_id: UUID, data: LessonUpdate) -> Lesson:
    """Atualiza uma aula (apenas campos enviados). Levanta LessonNotFoundError ou TechniqueNotFoundError."""
    lesson = get_lesson_by_id(db, lesson_id)
    payload = data.model_dump(exclude_unset=True)
    if "technique_id" in payload:
        tech = db.query(Technique).filter(Technique.id == payload["technique_id"]).first()
        if not tech:
            logger.info("update_lesson technique_not_found", extra={"technique_id": str(payload["technique_id"])})
            raise TechniqueNotFoundError("Técnica não encontrada.")
        lesson.technique_id = payload["technique_id"]
    for key in ("title", "slug", "video_url", "content", "order_index"):
        if key in payload:
            setattr(lesson, key, payload[key])
    db.commit()
    db.refresh(lesson)
    logger.info("update_lesson", extra={"lesson_id": str(lesson_id)})
    return lesson


def delete_lesson(db: Session, lesson_id: UUID) -> None:
    """Remove uma aula. Levanta LessonNotFoundError se não existir."""
    lesson = get_lesson_by_id(db, lesson_id)
    db.delete(lesson)
    db.commit()
    logger.info("delete_lesson", extra={"lesson_id": str(lesson_id)})
