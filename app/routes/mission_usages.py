"""Rotas de sync de MissionUsage (PB-01) e histórico (PB-03). Requerem autenticação."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user, require_aluno_not_frozen
from app.core.list_pagination import MAX_LIST_LIMIT
from app.database import get_db
from app.models import User
from app.schemas.mission_history import MissionHistoryItem, MissionHistoryResponse
from app.schemas.mission_usage import MissionUsageSyncRequest, MissionUsageSyncResponse
from app.services.mission_usage_service import get_mission_history, sync_mission_usages

router = APIRouter()


@router.post("/sync", response_model=MissionUsageSyncResponse)
async def mission_usages_sync(
    body: MissionUsageSyncRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_aluno_not_frozen),
):
    """Recebe lista de usos de missão do app e persiste para o usuário logado (PB-01)."""
    usages_dict = [u.model_dump() for u in body.usages]
    synced = await sync_mission_usages(db, current_user.id, usages_dict)
    return MissionUsageSyncResponse(synced=synced)


@router.get("/history", response_model=MissionHistoryResponse)
async def mission_usages_history(
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Últimas conclusões do usuário logado (PB-03). Paginação: limit máximo 50 por página."""
    items = await get_mission_history(db, current_user.id, limit=limit, offset=offset)
    return MissionHistoryResponse(
        missions=[MissionHistoryItem(**x) for x in items],
    )
