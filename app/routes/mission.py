from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.mission import MissionTodayResponse, MissionWeekResponse
from app.services.mission_service import get_mission_today_response, get_mission_week_response

router = APIRouter()


@router.get("/week", response_model=MissionWeekResponse)
async def mission_week(
    db: AsyncSession = Depends(get_db),
    level: str = "beginner",
    user_id: UUID | None = None,
    academy_id: UUID | None = None,
):
    payload = await get_mission_week_response(
        db, level=level, user_id=user_id, academy_id=academy_id
    )
    return JSONResponse(
        content=payload.model_dump(mode="json"),
        headers={"Cache-Control": "no-store"},
    )


@router.get("", response_model=MissionTodayResponse)
async def mission_today(
    db: AsyncSession = Depends(get_db),
    level: str = "beginner",
    user_id: UUID | None = None,
    review_after_days: int = 7,
    academy_id: UUID | None = None,
):
    payload = await get_mission_today_response(
        db,
        level=level,
        user_id=user_id,
        review_after_days=review_after_days,
        academy_id=academy_id,
    )
    if not payload:
        raise HTTPException(status_code=404, detail="Nenhuma missão disponível no momento.")
    return payload
