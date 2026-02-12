from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.metrics import UsageMetricsResponse
from app.services.metrics_service import get_usage_metrics

router = APIRouter()


@router.get("/usage", response_model=UsageMetricsResponse)
def metrics_usage(db: Session = Depends(get_db)):
    """Métricas básicas de uso: conclusões de lição (total, últimos 7 dias, usuários únicos)."""
    return get_usage_metrics(db)
