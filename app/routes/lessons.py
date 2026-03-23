from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LessonNotFoundError
from app.core.role_deps import require_read_access, require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas import LessonCreate, LessonRead, LessonUpdate
from app.services.lesson_service import (
    create_lesson,
    delete_lesson,
    get_lesson_by_id,
    list_lessons,
    update_lesson,
)

router = APIRouter()


@router.get("", response_model=list[LessonRead])
async def get_lessons(
    academy_id: UUID | None = Query(None, description="Se informado e academia tiver lição visível, retorna só ela."),
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(100, ge=1, le=500, description="Limite de resultados (máximo 500)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Lista aulas ordenadas por order_index com paginação."""
    return await list_lessons(db, academy_id=academy_id, offset=offset, limit=limit)


@router.get("/{lesson_id}", response_model=LessonRead)
async def get_lesson(
    lesson_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Retorna uma aula por ID."""
    lesson = await get_lesson_by_id(db, lesson_id)
    if not lesson:
        raise LessonNotFoundError()
    if lesson.academy_id:
        verify_academy_access(current_user, str(lesson.academy_id))
    return lesson


@router.post("", response_model=LessonRead, status_code=201)
async def post_lesson(
    data: LessonCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria uma nova aula."""
    return await create_lesson(db, data, audit_user_id=current_user.id)


@router.put("/{lesson_id}", response_model=LessonRead)
async def put_lesson(
    lesson_id: UUID,
    data: LessonUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza uma aula."""
    return await update_lesson(db, lesson_id, data, audit_user_id=current_user.id)


@router.delete("/{lesson_id}", status_code=204)
async def remove_lesson(
    lesson_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove uma aula."""
    await delete_lesson(db, lesson_id, audit_user_id=current_user.id)
