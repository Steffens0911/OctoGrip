"""Rotas de sync de MissionUsage (PB-01) e histórico (PB-03)."""
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.mission_history import MissionHistoryItem, MissionHistoryResponse
from app.schemas.mission_usage import MissionUsageSyncRequest, MissionUsageSyncResponse
from app.services.mission_usage_service import get_mission_history, sync_mission_usages

router = APIRouter()


@router.post("/sync", response_model=MissionUsageSyncResponse)
async def mission_usages_sync(body: MissionUsageSyncRequest, db: AsyncSession = Depends(get_db)):
    usages_dict = [u.model_dump() for u in body.usages]
    synced = await sync_mission_usages(db, body.user_id, usages_dict)
    return MissionUsageSyncResponse(synced=synced)


@router.get("/history", response_model=MissionHistoryResponse)
async def mission_usages_history(user_id: UUID, limit: int = 500, db: AsyncSession = Depends(get_db)):
    items = await get_mission_history(db, user_id, limit=min(limit, 500))
    return MissionHistoryResponse(missions=[MissionHistoryItem(**x) for x in items])
