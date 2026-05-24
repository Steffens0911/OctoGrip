from __future__ import annotations

import logging
from datetime import date, datetime
from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_time import today_in_app_tz, utc_now
from app.core.list_pagination import clamp_list_limit
from app.models import TrainingVideo, TrainingVideoDailyView, User
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)
from app.services.execution_service import total_points_for_user
from app.services.leveling_service import refresh_user_level

logger = logging.getLogger(__name__)

_ENTITY_TV = "TrainingVideo"

# Marca campo não enviado em PATCH (vs. enviado como null para limpar).
PATCH_UNSET = object()


def _optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


async def list_training_videos(
    db: AsyncSession,
    *,
    limit: int = 50,
    offset: int = 0,
) -> list[TrainingVideo]:
    safe_limit = clamp_list_limit(limit)
    safe_offset = max(0, int(offset))
    stmt = (
        select(TrainingVideo)
        .order_by(TrainingVideo.order_index.nulls_last(), TrainingVideo.created_at.desc())
        .offset(safe_offset)
        .limit(safe_limit)
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
    duration_seconds: int,
    position_description: str | None = None,
    academy_id: UUID | None = None,
    created_by_id: UUID | None = None,
    audit_user_id: UUID | None = None,
) -> TrainingVideo:
    video = TrainingVideo(
        title=title.strip(),
        youtube_url=youtube_url.strip(),
        points_per_day=points_per_day,
        is_active=is_active,
        duration_seconds=duration_seconds,
        position_description=_optional_text(position_description),
        academy_id=academy_id,
        created_by_id=created_by_id,
    )
    db.add(video)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_TV,
        entity_id=video.id,
        old_data=None,
        new_data=entity_snapshot_row(video),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(video)
    logger.info("create_training_video", extra={"video_id": str(video.id)})

    # Notifica alunos da academia sobre o novo vídeo (fire-and-forget).
    if video.is_active and video.academy_id:
        try:
            from app.services.notification_service import create_notifications_for_academy_students
            await create_notifications_for_academy_students(
                db,
                academy_id=video.academy_id,
                type="video_new",
                title="Novo vídeo diário! 🎬",
                body=video.title,
                data={"video_id": str(video.id)},
            )
        except Exception:
            logger.exception("create_training_video: erro ao criar notificações in-app")

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
    position_description: str | None | object = PATCH_UNSET,
    audit_user_id: UUID | None = None,
) -> TrainingVideo | None:
    video = await get_training_video(db, video_id)
    if not video:
        return None
    before = entity_snapshot_row(video)
    _was_active = video.is_active
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
    if position_description is not PATCH_UNSET:
        video.position_description = _optional_text(
            position_description if isinstance(position_description, str) else None
        )
    await db.flush()
    await db.refresh(video)
    after = entity_snapshot_row(video)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_TV,
            entity_id=video_id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(video)
    logger.info("update_training_video", extra={"video_id": str(video.id)})

    # Notifica alunos quando vídeo passa de inativo → ativo (fire-and-forget).
    became_active = not _was_active and video.is_active
    if became_active and video.academy_id:
        try:
            from app.services.notification_service import create_notifications_for_academy_students
            await create_notifications_for_academy_students(
                db,
                academy_id=video.academy_id,
                type="video_new",
                title="Novo vídeo diário! 🎬",
                body=video.title,
                data={"video_id": str(video.id)},
            )
        except Exception:
            logger.exception("update_training_video: erro ao criar notificações in-app")

    return video


async def delete_training_video(
    db: AsyncSession,
    video_id: UUID,
    *,
    audit_user_id: UUID | None = None,
) -> bool:
    video = await get_training_video(db, video_id)
    if not video:
        return False
    before = entity_snapshot_row(video)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_TV,
        entity_id=video_id,
        old_data=before,
        new_data=None,
        user_id=audit_user_id,
    )
    await db.delete(video)
    await db.commit()
    logger.info("delete_training_video", extra={"video_id": str(video.id)})
    return True


async def get_training_videos_for_user_today(
    db: AsyncSession,
    *,
    user: User,
    today: date | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[dict]:
    """Retorna vídeos ativos com status de conclusão diária para o usuário."""
    if today is None:
        today = today_in_app_tz()

    safe_limit = clamp_list_limit(limit)
    safe_offset = max(0, int(offset))

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
        .offset(safe_offset)
        .limit(safe_limit)
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
                "position_description": v.position_description,
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
    today = today_in_app_tz()

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

    now = utc_now()
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

