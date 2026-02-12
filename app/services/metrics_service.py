import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import LessonProgress

logger = logging.getLogger(__name__)


def get_usage_metrics(db: Session) -> dict:
    """
    Retorna métricas de uso baseadas em conclusões de lição (LessonProgress).
    Uma query por agregado para manter simples.
    """
    total = db.query(func.count(LessonProgress.id)).scalar() or 0

    since_7_days = datetime.now(timezone.utc) - timedelta(days=7)
    last_7 = (
        db.query(func.count(LessonProgress.id))
        .filter(LessonProgress.completed_at >= since_7_days)
        .scalar()
    ) or 0

    unique_users = db.query(func.count(func.distinct(LessonProgress.user_id))).scalar() or 0

    result = {
        "total_completions": total,
        "completions_last_7_days": last_7,
        "unique_users_completed": unique_users,
    }
    logger.info("get_usage_metrics", extra=result)
    return result
