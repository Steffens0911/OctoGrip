"""Rotas de sync de MissionUsage (PB-01) e histórico (PB-03). Requerem autenticação."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.auth_deps import get_current_user
from app.models import User
from app.schemas.mission_history import MissionHistoryItem, MissionHistoryResponse
from app.schemas.mission_usage import MissionUsageSyncRequest, MissionUsageSyncResponse
from app.services.mission_usage_service import get_mission_history, sync_mission_usages

router = APIRouter()


@router.post("/sync", response_model=MissionUsageSyncResponse)
def mission_usages_sync(
    body: MissionUsageSyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Recebe lista de usos de missão do app e persiste para o usuário logado (PB-01)."""
    usages_dict = [u.model_dump() for u in body.usages]
    synced = sync_mission_usages(db, current_user.id, usages_dict)
    return MissionUsageSyncResponse(synced=synced)


@router.get("/history", response_model=MissionHistoryResponse)
def mission_usages_history(
    limit: int = 500,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Últimas N missões concluídas do usuário logado (PB-03). Default 500."""
    items = get_mission_history(db, current_user.id, limit=min(limit, 500))
    return MissionHistoryResponse(
        missions=[MissionHistoryItem(**x) for x in items],
    )
