from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.auth_deps import get_current_user
from app.models import User
from app.schemas.training_feedback import TrainingFeedbackRequest, TrainingFeedbackResponse
from app.services.training_feedback_service import create_feedback

router = APIRouter()


@router.post("", response_model=TrainingFeedbackResponse, status_code=201)
def training_feedback(
    body: TrainingFeedbackRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registra posição em que o usuário logado teve dificuldade no treino (observação opcional)."""
    feedback = create_feedback(
        db,
        user_id=current_user.id,
        position_id=body.position_id,
        observation=body.observation,
    )
    return TrainingFeedbackResponse(
        id=feedback.id,
        user_id=feedback.user_id,
        position_id=feedback.position_id,
        observation=feedback.note,
        created_at=feedback.created_at,
    )
