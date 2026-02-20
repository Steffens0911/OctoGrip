from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.metrics import get_metrics_response
from app.database import get_db
from app.schemas.metrics import UsageMetricsResponse
from app.services.metrics_service import get_usage_metrics

router = APIRouter()


@router.get("/usage", response_model=UsageMetricsResponse)
async def metrics_usage(db: AsyncSession = Depends(get_db)):
    """Métricas básicas de uso: conclusões de lição (total, últimos 7 dias, usuários únicos)."""
    return await get_usage_metrics(db)


@router.get("/prometheus")
async def metrics_prometheus():
    """Endpoint Prometheus para scraping de métricas."""
    if not settings.ENABLE_METRICS:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Métricas desabilitadas")
    
    metrics_data, content_type = get_metrics_response()
    return Response(content=metrics_data, media_type=content_type)
