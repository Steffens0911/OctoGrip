"""Conclusão por missão: POST /mission_complete (requer autenticação)."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.auth_deps import get_current_user
from app.models import User
from app.schemas.mission_complete import MissionCompleteRequest, MissionCompleteResponse
from app.services.mission_complete_service import complete_mission

router = APIRouter()


@router.post("", response_model=MissionCompleteResponse, status_code=201)
async def mission_complete(
    body: MissionCompleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registra conclusão da missão pelo usuário logado. 409 se já concluiu."""
    usage = await complete_mission(
        db, current_user.id, body.mission_id, usage_type=body.usage_type
    )
    assert usage.mission_id is not None
    return MissionCompleteResponse(
        user_id=usage.user_id,
        mission_id=usage.mission_id,
        completed_at=usage.completed_at,
        points_awarded=int(usage.points_awarded or 0),
    )
