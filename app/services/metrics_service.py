import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import LessonProgress, MissionUsage

logger = logging.getLogger(__name__)


def get_usage_metrics(db: Session) -> dict:
    """
    Retorna métricas de uso (LessonProgress) e retenção (MissionUsage, PB-02).
    """
    total = db.query(func.count(LessonProgress.id)).scalar() or 0

    since_7_days = datetime.now(timezone.utc) - timedelta(days=7)
    last_7 = (
        db.query(func.count(LessonProgress.id))
        .filter(LessonProgress.completed_at >= since_7_days)
        .scalar()
    ) or 0

    unique_users = db.query(func.count(func.distinct(LessonProgress.user_id))).scalar() or 0

    before = (
        db.query(func.count(MissionUsage.id)).filter(MissionUsage.usage_type == "before_training").scalar()
    ) or 0
    after = (
        db.query(func.count(MissionUsage.id)).filter(MissionUsage.usage_type == "after_training").scalar()
    ) or 0
    total_usage = before + after
    before_percent = round((before / total_usage * 100.0), 1) if total_usage > 0 else 0.0

    result = {
        "total_completions": total,
        "completions_last_7_days": last_7,
        "unique_users_completed": unique_users,
        "before_training_count": before,
        "after_training_count": after,
        "before_training_percent": before_percent,
    }
    logger.info("get_usage_metrics", extra=result)
    return result
