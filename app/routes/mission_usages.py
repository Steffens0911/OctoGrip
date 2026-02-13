"""Rotas de sync de MissionUsage (PB-01) e histórico (PB-03)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.mission_history import MissionHistoryItem, MissionHistoryResponse
from app.schemas.mission_usage import MissionUsageSyncRequest, MissionUsageSyncResponse
from app.services.mission_usage_service import get_mission_history, sync_mission_usages

router = APIRouter()


@router.post("/sync", response_model=MissionUsageSyncResponse)
def mission_usages_sync(
    body: MissionUsageSyncRequest,
    db: Session = Depends(get_db),
):
    """Recebe lista de usos de missão do app e persiste no backend (PB-01)."""
    usages_dict = [u.model_dump() for u in body.usages]
    synced = sync_mission_usages(db, body.user_id, usages_dict)
    return MissionUsageSyncResponse(synced=synced)


@router.get("/history", response_model=MissionHistoryResponse)
def mission_usages_history(
    user_id: UUID,
    limit: int = 7,
    db: Session = Depends(get_db),
):
    """Últimas 7 (ou N) missões concluídas do usuário (PB-03)."""
    items = get_mission_history(db, user_id, limit=min(limit, 50))
    return MissionHistoryResponse(
        missions=[MissionHistoryItem(**x) for x in items],
    )
