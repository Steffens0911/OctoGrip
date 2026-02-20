from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.auth_deps import get_current_user
from app.models import User
from app.schemas.lesson_complete import (
    LessonCompleteRequest,
    LessonCompleteResponse,
    LessonCompleteStatusResponse,
)
from app.services.lesson_complete_service import complete_lesson, is_lesson_completed

router = APIRouter()


@router.get("/status", response_model=LessonCompleteStatusResponse)
def lesson_complete_status(
    lesson_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Indica se a lição já foi concluída pelo usuário logado (para exibir botão desabilitado)."""
    completed = is_lesson_completed(db, current_user.id, lesson_id)
    return LessonCompleteStatusResponse(completed=completed)


@router.post("", response_model=LessonCompleteResponse, status_code=201)
def lesson_complete(
    body: LessonCompleteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registra conclusão da lição para o usuário logado. Impede conclusão duplicada."""
    progress = complete_lesson(db, current_user.id, body.lesson_id)
    return LessonCompleteResponse(
        lesson_id=progress.lesson_id,
        user_id=progress.user_id,
        completed_at=progress.completed_at,
    )
