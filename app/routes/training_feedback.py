import traceback
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.auth_deps import get_current_user
from app.models import User
from app.schemas.training_feedback import TrainingFeedbackRequest, TrainingFeedbackResponse
from app.services.training_feedback_service import create_feedback

router = APIRouter()


@router.post("", response_model=TrainingFeedbackResponse, status_code=201)
async def training_feedback(
    body: TrainingFeedbackRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registra dificuldade do treino (observação opcional), sem Position."""
    try:
        feedback = await create_feedback(
            db,
            user_id=current_user.id,
            observation=body.observation,
        )
        return TrainingFeedbackResponse(
            id=feedback.id,
            user_id=feedback.user_id,
            observation=feedback.note,
            created_at=feedback.created_at,
        )
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
