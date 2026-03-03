from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.metrics import get_metrics_response
from app.core.role_deps import require_admin_or_manager, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.metrics import UsageMetricsResponse
from app.services.metrics_service import get_usage_metrics, get_usage_metrics_for_academy

router = APIRouter()


@router.get("/usage", response_model=UsageMetricsResponse)
async def metrics_usage(db: AsyncSession = Depends(get_db)):
    """Métricas básicas de uso globais: conclusões de lição e retenção."""
    return await get_usage_metrics(db)


@router.get("/usage/by_academy", response_model=UsageMetricsResponse)
async def metrics_usage_by_academy(
    academy_id: UUID = Query(..., description="Academia para filtrar métricas de uso"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager),
):
    """
    Métricas de uso filtradas por academy_id.

    - Administrador pode ver qualquer academia.
    - Gerente de academia só pode ver a própria academia.
    """
    verify_academy_access(current_user, str(academy_id))
    return await get_usage_metrics_for_academy(db, academy_id)


@router.get("/prometheus")
async def metrics_prometheus():
    """Endpoint Prometheus para scraping de métricas."""
    if not settings.ENABLE_METRICS:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Métricas desabilitadas")
    
    metrics_data, content_type = get_metrics_response()
    return Response(content=metrics_data, media_type=content_type)
