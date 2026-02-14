"""Serviço de sync de MissionUsage (PB-01) e conclusão por missão."""
import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.exceptions import UserNotFoundError
from app.models import Lesson, LessonProgress, MissionUsage, User

logger = logging.getLogger(__name__)


def sync_mission_usages(
    db: Session,
    user_id: UUID,
    usages: list[dict],
) -> int:
    """
    Insere registros de uso enviados pelo app (legado: lesson_id).
    Valida user e lesson; ignora duplicatas.
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
            mission_id=None,
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
    Últimas N conclusões (por missão ou legado por lição).
    Retorna dict com lesson_id (opcional), lesson_title, completed_at, usage_type.
    """
    from app.models import Mission

    usage_rows = (
        db.query(MissionUsage)
        .filter(MissionUsage.user_id == user_id)
        .options(
            joinedload(MissionUsage.mission).joinedload(Mission.technique),
            joinedload(MissionUsage.lesson),
        )
        .order_by(MissionUsage.completed_at.desc())
        .limit(limit * 2)
        .all()
    )
    items = []
    for r in usage_rows:
        if r.mission_id and r.mission and r.mission.technique:
            items.append({
                "lesson_id": None,
                "lesson_title": r.mission.technique.name,
                "completed_at": r.completed_at,
                "usage_type": r.usage_type,
            })
        elif r.lesson_id and r.lesson:
            items.append({
                "lesson_id": r.lesson_id,
                "lesson_title": r.lesson.title,
                "completed_at": r.completed_at,
                "usage_type": r.usage_type,
            })

    lesson_ids_in_usage = {r.lesson_id for r in usage_rows if r.lesson_id is not None}

    progress_q = (
        db.query(LessonProgress)
        .filter(LessonProgress.user_id == user_id)
        .options(joinedload(LessonProgress.lesson))
        .order_by(LessonProgress.completed_at.desc())
    )
    if lesson_ids_in_usage:
        progress_q = progress_q.filter(~LessonProgress.lesson_id.in_(lesson_ids_in_usage))
    progress_rows = progress_q.limit(limit * 2).all()
    for r in progress_rows:
        items.append({
            "lesson_id": r.lesson_id,
            "lesson_title": r.lesson.title if r.lesson else "",
            "completed_at": r.completed_at,
            "usage_type": "after_training",
        })

    items.sort(key=lambda x: x["completed_at"], reverse=True)
    return items[:limit]
