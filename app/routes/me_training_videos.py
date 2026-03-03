from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.database import get_db
from app.models import User
from app.schemas.training_video import (
    TrainingVideoCompletionResponse,
    TrainingVideoStudentRead,
)
from app.services.training_video_service import (
    complete_training_video_for_user,
    get_training_videos_for_user_today,
    get_training_video,
)

router = APIRouter()


@router.get("/training_videos/today", response_model=list[TrainingVideoStudentRead])
async def my_training_videos_today(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista vídeos de treinamento disponíveis hoje para o usuário logado."""
    raw = await get_training_videos_for_user_today(db, user=current_user)
    return [TrainingVideoStudentRead(**item) for item in raw]


@router.post(
    "/training_videos/{video_id}/complete",
    response_model=TrainingVideoCompletionResponse,
)
async def my_training_video_complete(
    video_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registra conclusão diária de um vídeo de treinamento (máx. 1 vez ao dia)."""
    video = await get_training_video(db, video_id)
    if not video or not video.is_active:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Vídeo de treinamento não encontrado.")
    payload = await complete_training_video_for_user(
        db,
        user=current_user,
        video=video,
    )
    return TrainingVideoCompletionResponse(**payload)

