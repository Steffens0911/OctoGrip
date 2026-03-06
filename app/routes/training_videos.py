from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError
from app.core.role_deps import require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.training_video import (
    TrainingVideoAdminRead,
    TrainingVideoCreate,
    TrainingVideoUpdate,
)
from app.services.training_video_service import (
    create_training_video,
    delete_training_video,
    get_training_video,
    list_training_videos,
    update_training_video,
)

router = APIRouter()


@router.get("", response_model=list[TrainingVideoAdminRead])
async def training_videos_list(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Lista todos os vídeos de treinamento (admin/professor)."""
    videos = await list_training_videos(db)
    return [TrainingVideoAdminRead.model_validate(v) for v in videos]


@router.post("", response_model=TrainingVideoAdminRead, status_code=201)
async def training_video_create(
    body: TrainingVideoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria um novo vídeo de treinamento.

    - Administrador global: cria vídeos globais (academy_id = NULL).
    - Demais (gestor/professor): criam vídeos locais para sua própria academia.
    """
    academy_id: UUID | None = None
    if current_user.role != "administrador":
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia para criar vídeos de treinamento.")
        academy_id = current_user.academy_id
    video = await create_training_video(
        db,
        title=body.title,
        youtube_url=body.youtube_url,
        points_per_day=body.points_per_day,
        is_active=body.is_active,
        duration_seconds=body.duration_seconds,
        academy_id=academy_id,
        created_by_id=current_user.id,
    )
    return TrainingVideoAdminRead.model_validate(video)


@router.put("/{video_id}", response_model=TrainingVideoAdminRead)
async def training_video_update(
    video_id: UUID,
    body: TrainingVideoUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza um vídeo de treinamento."""
    video = await get_training_video(db, video_id)
    if not video:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Vídeo de treinamento não encontrado.")
    # Gestores/professores só podem editar vídeos locais da sua própria academia.
    if current_user.role != "administrador":
        if current_user.academy_id is None or video.academy_id != current_user.academy_id:
            raise ForbiddenError("Você não tem permissão para editar este vídeo.")
    payload = body.model_dump(exclude_unset=True)
    updated = await update_training_video(
        db,
        video_id,
        title=payload.get("title"),
        youtube_url=payload.get("youtube_url"),
        points_per_day=payload.get("points_per_day"),
        is_active=payload.get("is_active"),
        duration_seconds=payload.get("duration_seconds"),
    )
    assert updated is not None
    return TrainingVideoAdminRead.model_validate(updated)


@router.delete("/{video_id}", status_code=204)
async def training_video_delete(
    video_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove um vídeo de treinamento."""
    video = await get_training_video(db, video_id)
    if not video:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Vídeo de treinamento não encontrado.")
    if current_user.role != "administrador":
        if current_user.academy_id is None or video.academy_id != current_user.academy_id:
            raise ForbiddenError("Você não tem permissão para remover este vídeo.")
    ok = await delete_training_video(db, video_id)
    if not ok:
        from app.core.exceptions import NotFoundError

        raise NotFoundError("Vídeo de treinamento não encontrado.")
    return None

