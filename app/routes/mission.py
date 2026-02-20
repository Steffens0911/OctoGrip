from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import NotFoundError
from app.database import get_db
from app.models import User
from app.schemas.mission import MissionTodayResponse, MissionWeekResponse
from app.services.mission_service import get_mission_today_response, get_mission_week_response

router = APIRouter()


@router.get("/week", response_model=MissionWeekResponse)
async def mission_week(
    db: AsyncSession = Depends(get_db),
    level: str = "beginner",
    current_user: User = Depends(get_current_user),
):
    """
    Retorna as 3 missões da semana (Missão 1, 2, 3) para a academia do usuário autenticado.
    Requer autenticação obrigatória.
    """
    payload = await get_mission_week_response(
        db, level=level, user_id=current_user.id, academy_id=current_user.academy_id
    )
    return JSONResponse(
        content=payload.model_dump(mode="json"),
        headers={"Cache-Control": "no-store"},
    )


@router.get("", response_model=MissionTodayResponse)
async def mission_today(
    db: AsyncSession = Depends(get_db),
    level: str = "beginner",
    review_after_days: int = 7,
    current_user: User = Depends(get_current_user),
):
    """
    Retorna a missão do dia por nível para a academia do usuário autenticado.
    Requer autenticação obrigatória.
    """
    payload = await get_mission_today_response(
        db,
        level=level,
        user_id=current_user.id,
        review_after_days=review_after_days,
        academy_id=current_user.academy_id,
    )
    if not payload:
        raise NotFoundError("Nenhuma missão disponível no momento.")
    return payload
