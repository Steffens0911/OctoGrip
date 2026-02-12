from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.lesson_complete import LessonCompleteRequest, LessonCompleteResponse
from app.services.lesson_complete_service import complete_lesson

router = APIRouter()


@router.post("", response_model=LessonCompleteResponse, status_code=201)
def lesson_complete(
    body: LessonCompleteRequest,
    db: Session = Depends(get_db),
):
    """Registra conclusão da lição para o usuário. Impede conclusão duplicada."""
    progress = complete_lesson(db, body.user_id, body.lesson_id)
    return LessonCompleteResponse(
        lesson_id=progress.lesson_id,
        user_id=progress.user_id,
        completed_at=progress.completed_at,
    )
