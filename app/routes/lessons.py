from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
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
    db: AsyncSession = Depends(get_db),
):
    """Lista aulas ordenadas por order_index. Com academy_id, retorna apenas a lição visível da academia (se houver)."""
    return await list_lessons(db, academy_id=academy_id)


@router.get("/{lesson_id}", response_model=LessonRead)
async def get_lesson(lesson_id: UUID, db: AsyncSession = Depends(get_db)):
    """Retorna uma aula por ID. 404 se não existir."""
    return await get_lesson_by_id(db, lesson_id)


@router.post("", response_model=LessonRead, status_code=201)
async def post_lesson(data: LessonCreate, db: AsyncSession = Depends(get_db)):
    """Cria uma nova aula. 404 se technique_id não existir."""
    return await create_lesson(db, data)


@router.put("/{lesson_id}", response_model=LessonRead)
async def put_lesson(lesson_id: UUID, data: LessonUpdate, db: AsyncSession = Depends(get_db)):
    """Atualiza uma aula (campos opcionais). 404 se lição ou técnica não existir."""
    return await update_lesson(db, lesson_id, data)


@router.delete("/{lesson_id}", status_code=204)
async def remove_lesson(lesson_id: UUID, db: AsyncSession = Depends(get_db)):
    """Remove uma aula. 404 se não existir."""
    await delete_lesson(db, lesson_id)
