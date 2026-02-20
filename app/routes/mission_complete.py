"""Conclusão por missão: POST /mission_complete."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.mission_complete import MissionCompleteRequest, MissionCompleteResponse
from app.services.mission_complete_service import complete_mission

router = APIRouter()


@router.post("", response_model=MissionCompleteResponse, status_code=201)
async def mission_complete(body: MissionCompleteRequest, db: AsyncSession = Depends(get_db)):
    usage = await complete_mission(db, body.user_id, body.mission_id, usage_type=body.usage_type)
    assert usage.mission_id is not None
    return MissionCompleteResponse(user_id=usage.user_id, mission_id=usage.mission_id, completed_at=usage.completed_at)
