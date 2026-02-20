from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.metrics import UsageMetricsResponse
from app.services.metrics_service import get_usage_metrics

router = APIRouter()


@router.get("/usage", response_model=UsageMetricsResponse)
async def metrics_usage(db: AsyncSession = Depends(get_db)):
    """Métricas básicas de uso: conclusões de lição (total, últimos 7 dias, usuários únicos)."""
    return await get_usage_metrics(db)
