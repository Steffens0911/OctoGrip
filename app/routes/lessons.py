from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

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
def get_lessons(
    academy_id: UUID | None = Query(None, description="Se informado e academia tiver lição visível, retorna só ela."),
    db: Session = Depends(get_db),
):
    """Lista aulas ordenadas por order_index. Com academy_id, retorna apenas a lição visível da academia (se houver)."""
    return list_lessons(db, academy_id=academy_id)


@router.get("/{lesson_id}", response_model=LessonRead)
def get_lesson(lesson_id: UUID, db: Session = Depends(get_db)):
    """Retorna uma aula por ID. 404 se não existir."""
    return get_lesson_by_id(db, lesson_id)


@router.post("", response_model=LessonRead, status_code=201)
def post_lesson(data: LessonCreate, db: Session = Depends(get_db)):
    """Cria uma nova aula. 404 se technique_id não existir."""
    return create_lesson(db, data)


@router.put("/{lesson_id}", response_model=LessonRead)
def put_lesson(lesson_id: UUID, data: LessonUpdate, db: Session = Depends(get_db)):
    """Atualiza uma aula (campos opcionais). 404 se lição ou técnica não existir."""
    return update_lesson(db, lesson_id, data)


@router.delete("/{lesson_id}", status_code=204)
def remove_lesson(lesson_id: UUID, db: Session = Depends(get_db)):
    """Remove uma aula. 404 se não existir."""
    delete_lesson(db, lesson_id)
