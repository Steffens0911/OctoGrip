from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.cache import app_cache
from app.core.exceptions import NotFoundError
from app.database import get_db
from app.models import User
from app.schemas.mission import MissionTodayResponse, MissionWeekResponse
from app.services.mission_service import get_mission_today_response, get_mission_week_response

router = APIRouter()
_CACHE_TTL = 30  # segundos: reduz carga nas trocas de tela


def _week_cache_key(user_id: UUID, level: str, academy_id: UUID | None) -> str:
    return f"mission_week:{user_id}:{level}:{academy_id}"


def _today_cache_key(user_id: UUID, level: str, academy_id: UUID | None, review_after_days: int) -> str:
    return f"mission_today:{user_id}:{level}:{academy_id}:{review_after_days}"


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
    key = _week_cache_key(current_user.id, level, current_user.academy_id)
    cached = await app_cache.get(key)
    if cached is not None:
        return JSONResponse(
            content=cached,
            headers={"Cache-Control": "private, max-age=25"},
        )
    payload = await get_mission_week_response(
        db, level=level, user_id=current_user.id, academy_id=current_user.academy_id
    )
    await app_cache.set(key, payload.model_dump(mode="json"), ttl=_CACHE_TTL)
    return JSONResponse(
        content=payload.model_dump(mode="json"),
        headers={"Cache-Control": "private, max-age=25"},
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
    key = _today_cache_key(
        current_user.id, level, current_user.academy_id, review_after_days
    )
    cached = await app_cache.get(key)
    if cached is not None:
        return MissionTodayResponse.model_validate(cached)
    payload = await get_mission_today_response(
        db,
        level=level,
        user_id=current_user.id,
        review_after_days=review_after_days,
        academy_id=current_user.academy_id,
    )
    if not payload:
        raise NotFoundError("Nenhuma missão disponível no momento.")
    await app_cache.set(key, payload.model_dump(mode="json"), ttl=_CACHE_TTL)
    return payload
