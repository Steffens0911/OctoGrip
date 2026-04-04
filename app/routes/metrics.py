from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.exceptions import ForbiddenError
from app.core.metrics import get_metrics_response
from app.core.role_deps import (
    require_admin,
    require_admin_manager_or_supervisor,
    require_admin_or_supervisor,
    verify_academy_access,
)
from app.database import get_db
from app.models import User
from app.schemas.metrics import UsageMetricsResponse
from app.services.metrics_service import get_usage_metrics, get_usage_metrics_for_academy

router = APIRouter()


@router.get("/usage", response_model=UsageMetricsResponse)
async def metrics_usage(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_supervisor),
):
    """Métricas de uso: globais para administrador; supervisor vê só a própria academia."""
    if current_user.role == "supervisor":
        if current_user.academy_id is None:
            raise ForbiddenError(
                "Supervisor sem academia vinculada não pode consultar métricas de uso."
            )
        return await get_usage_metrics_for_academy(db, current_user.academy_id)
    return await get_usage_metrics(db)


@router.get("/usage/by_academy", response_model=UsageMetricsResponse)
async def metrics_usage_by_academy(
    academy_id: UUID = Query(..., description="Academia para filtrar métricas de uso"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """
    Métricas de uso filtradas por academy_id.

    - Administrador pode ver qualquer academia.
    - Gerente de academia ou supervisor só a própria academia.
    """
    verify_academy_access(current_user, str(academy_id))
    return await get_usage_metrics_for_academy(db, academy_id)


@router.get("/prometheus")
async def metrics_prometheus(current_user: User = Depends(require_admin)):
    """Endpoint Prometheus para scraping de métricas."""
    _ = current_user
    if not settings.ENABLE_METRICS:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Métricas desabilitadas")

    metrics_data, content_type = get_metrics_response()
    return Response(content=metrics_data, media_type=content_type)
