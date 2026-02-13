"""Serviço de sync de MissionUsage (PB-01)."""
import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import UserNotFoundError
from app.models import Lesson, MissionUsage, User

logger = logging.getLogger(__name__)


def sync_mission_usages(
    db: Session,
    user_id: UUID,
    usages: list[dict],
) -> int:
    """
    Insere registros de uso enviados pelo app.
    Valida user e lesson; ignora duplicatas (mesmo user, lesson, completed_at).
    Retorna quantidade inserida.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        logger.info("sync_mission_usages user_not_found", extra={"user_id": str(user_id)})
        raise UserNotFoundError("Usuário não encontrado.")

    synced = 0
    for u in usages:
        lesson_id = u.get("lesson_id")
        if not lesson_id:
            continue
        if isinstance(lesson_id, str):
            try:
                lesson_id = UUID(lesson_id)
            except ValueError:
                continue
        lesson = db.query(Lesson).filter(Lesson.id == lesson_id).first()
        if not lesson:
            logger.debug("sync_mission_usages lesson_not_found", extra={"lesson_id": str(lesson_id)})
            continue

        opened_at = _parse_dt(u.get("opened_at"))
        completed_at = _parse_dt(u.get("completed_at"))
        usage_type = u.get("usage_type") or "after_training"
        if usage_type not in ("before_training", "after_training"):
            usage_type = "after_training"

        existing = (
            db.query(MissionUsage)
            .filter(
                MissionUsage.user_id == user_id,
                MissionUsage.lesson_id == lesson_id,
                MissionUsage.completed_at == completed_at,
            )
            .first()
        )
        if existing:
            continue

        record = MissionUsage(
            user_id=user_id,
            lesson_id=lesson_id,
            opened_at=opened_at,
            completed_at=completed_at,
            usage_type=usage_type,
        )
        db.add(record)
        synced += 1

    if synced > 0:
        db.commit()
    logger.info(
        "sync_mission_usages",
        extra={"user_id": str(user_id), "synced": synced, "total_sent": len(usages)},
    )
    return synced


def _parse_dt(value) -> datetime:
    if value is None:
        return datetime.now(timezone.utc)
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def get_mission_history(db: Session, user_id: UUID, limit: int = 7) -> list[dict]:
    """
    Últimas N missões concluídas do usuário (PB-03).
    Ordenado por completed_at DESC. Retorna lista de dict com lesson_id, lesson_title, completed_at, usage_type.
    """
    rows = (
        db.query(MissionUsage)
        .filter(MissionUsage.user_id == user_id)
        .options(joinedload(MissionUsage.lesson))
        .order_by(MissionUsage.completed_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "lesson_id": r.lesson_id,
            "lesson_title": r.lesson.title if r.lesson else "",
            "completed_at": r.completed_at,
            "usage_type": r.usage_type,
        }
        for r in rows
    ]
