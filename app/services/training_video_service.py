from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import TrainingVideo, TrainingVideoDailyView, User
from app.services.execution_service import total_points_for_user
from app.services.leveling_service import refresh_user_level

logger = logging.getLogger(__name__)


async def list_training_videos(db: AsyncSession) -> list[TrainingVideo]:
    stmt = (
        select(TrainingVideo)
        .order_by(TrainingVideo.order_index.nulls_last(), TrainingVideo.created_at.desc())
    )
    return (await db.execute(stmt)).scalars().all()


async def get_training_video(db: AsyncSession, video_id: UUID) -> TrainingVideo | None:
    return (await db.execute(
        select(TrainingVideo).where(TrainingVideo.id == video_id)
    )).scalar_one_or_none()


async def create_training_video(
    db: AsyncSession,
    *,
    title: str,
    youtube_url: str,
    points_per_day: int,
    is_active: bool = True,
    duration_seconds: int | None = None,
    academy_id: UUID | None = None,
    created_by_id: UUID | None = None,
) -> TrainingVideo:
    video = TrainingVideo(
        title=title.strip(),
        youtube_url=youtube_url.strip(),
        points_per_day=points_per_day,
        is_active=is_active,
        duration_seconds=duration_seconds,
        academy_id=academy_id,
        created_by_id=created_by_id,
    )
    db.add(video)
    await db.commit()
    await db.refresh(video)
    logger.info("create_training_video", extra={"video_id": str(video.id)})
    return video


async def update_training_video(
    db: AsyncSession,
    video_id: UUID,
    *,
    title: str | None = None,
    youtube_url: str | None = None,
    points_per_day: int | None = None,
    is_active: bool | None = None,
    duration_seconds: int | None = None,
) -> TrainingVideo | None:
    video = await get_training_video(db, video_id)
    if not video:
        return None
    if title is not None:
        video.title = title.strip()
    if youtube_url is not None:
        video.youtube_url = youtube_url.strip()
    if points_per_day is not None:
        video.points_per_day = points_per_day
    if is_active is not None:
        video.is_active = is_active
    if duration_seconds is not None:
        video.duration_seconds = duration_seconds
    await db.commit()
    await db.refresh(video)
    logger.info("update_training_video", extra={"video_id": str(video.id)})
    return video


async def delete_training_video(db: AsyncSession, video_id: UUID) -> bool:
    video = await get_training_video(db, video_id)
    if not video:
        return False
    await db.delete(video)
    await db.commit()
    logger.info("delete_training_video", extra={"video_id": str(video.id)})
    return True


async def get_training_videos_for_user_today(
    db: AsyncSession,
    *,
    user: User,
    today: date | None = None,
) -> list[dict]:
    """Retorna vídeos ativos com status de conclusão diária para o usuário."""
    if today is None:
        today = datetime.now(timezone.utc).date()

    # Vídeos globais (academy_id IS NULL) + vídeos locais da academia do usuário (se houver).
    base_query = select(TrainingVideo).where(TrainingVideo.is_active.is_(True))
    if user.academy_id is not None:
        base_query = base_query.where(
            or_(
                TrainingVideo.academy_id.is_(None),
                TrainingVideo.academy_id == user.academy_id,
            )
        )
    else:
        base_query = base_query.where(TrainingVideo.academy_id.is_(None))

    videos = (await db.execute(
        base_query.order_by(
            TrainingVideo.order_index.nulls_last(),
            TrainingVideo.created_at.desc(),
        )
    )).scalars().all()
    if not videos:
        return []

    video_ids = [v.id for v in videos]
    views = (await db.execute(
        select(TrainingVideoDailyView).where(
            TrainingVideoDailyView.user_id == user.id,
            TrainingVideoDailyView.training_video_id.in_(video_ids),
        )
    )).scalars().all()

    by_video: dict[UUID, list[TrainingVideoDailyView]] = {}
    for view in views:
        by_video.setdefault(view.training_video_id, []).append(view)

    result: list[dict] = []
    for v in videos:
        user_views = by_video.get(v.id, [])
        last_completed_at = max((vv.completed_at for vv in user_views), default=None)
        has_completed_today = any(vv.view_date == today for vv in user_views)
        result.append(
            {
                "id": v.id,
                "title": v.title,
                "youtube_url": v.youtube_url,
                "points_per_day": v.points_per_day,
                "duration_seconds": v.duration_seconds,
                "academy_id": v.academy_id,
                "academy_name": getattr(v.academy, "name", None) if hasattr(v, "academy") else None,
                "has_completed_today": has_completed_today,
                "last_completed_at": last_completed_at,
            }
        )
    return result


async def complete_training_video_for_user(
    db: AsyncSession,
    *,
    user: User,
    video: TrainingVideo,
) -> dict:
    """Registra uma visualização diária, garantindo no máximo 1 pontuação por dia."""
    today = datetime.now(timezone.utc).date()

    existing = (await db.execute(
        select(TrainingVideoDailyView).where(
            TrainingVideoDailyView.user_id == user.id,
            TrainingVideoDailyView.training_video_id == video.id,
            TrainingVideoDailyView.view_date == today,
        )
    )).scalar_one_or_none()

    if existing:
        points_total = await total_points_for_user(db, user.id)
        await refresh_user_level(db, user.id, total_points=points_total)
        return {
            "training_video_id": video.id,
            "has_completed_today": True,
            "already_completed_today": True,
            "points_granted": None,
            "new_points_balance": points_total,
            "message": "Este vídeo já foi contabilizado hoje.",
        }

    now = datetime.now(timezone.utc)
    view = TrainingVideoDailyView(
        user_id=user.id,
        training_video_id=video.id,
        view_date=today,
        completed_at=now,
        points_awarded=video.points_per_day,
    )
    db.add(view)
    await db.commit()
    await db.refresh(view)

    points_total = await total_points_for_user(db, user.id)
    await refresh_user_level(db, user.id, total_points=points_total)

    logger.info(
        "complete_training_video_for_user",
        extra={
            "user_id": str(user.id),
            "training_video_id": str(video.id),
            "points_awarded": view.points_awarded,
        },
    )

    return {
        "training_video_id": video.id,
        "has_completed_today": True,
        "already_completed_today": False,
        "points_granted": view.points_awarded,
        "new_points_balance": points_total,
        "message": "Pontos de vídeo de treinamento registrados.",
    }

