"""Estatísticas de treino do aluno autenticado (últimos 30 dias + total)."""

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

_APP_TZ = ZoneInfo("America/Sao_Paulo")

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.cache import app_cache
from app.database import get_db
from app.models import AttendanceRecord, AttendanceSession, User
from app.models.technique_execution import TechniqueExecution
from app.models.training_video import TrainingVideoDailyView
from app.services.training_stats_cache import (
    TRAINING_STATS_TTL_SEC,
    training_stats_cache_key,
)

router = APIRouter()


class TrainingStatsRead(BaseModel):
    workouts_last_30_days: int
    days_since_last_workout: int | None
    positions_last_30_days: int
    positions_total: int
    avg_top10_workouts_last_30_days: float | None
    avg_top10_positions_last_30_days: float | None
    ranking_positions_total: int | None
    ranking_positions_total_out_of: int | None
    videos_last_30_days: int
    avg_top10_videos_last_30_days: float | None
    ranking_videos_last_30_days: int | None


@router.get("/training_stats", response_model=TrainingStatsRead)
async def my_training_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Estatísticas de treino do aluno: presenças nas chamadas e posições confirmadas.

    Consolidado em até 4 idas ao banco (era ~14) + cache Redis curto, pois é um
    dos endpoints chamados no boot do app.
    """
    cache_key = training_stats_cache_key(current_user.id)
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return TrainingStatsRead(**cached)

    now = datetime.now(UTC)
    cutoff = now - timedelta(days=30)

    # ── Métricas do próprio aluno: 5 contagens em uma única ida ao banco ──
    workouts_30d_sq = (
        select(func.count(AttendanceRecord.id))
        .select_from(AttendanceRecord)
        .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
        .where(
            AttendanceRecord.user_id == current_user.id,
            AttendanceRecord.checked_in_at >= cutoff,
        )
        .scalar_subquery()
    )
    last_checkin_sq = (
        select(func.max(AttendanceRecord.checked_in_at))
        .where(AttendanceRecord.user_id == current_user.id)
        .scalar_subquery()
    )
    positions_30d_sq = (
        select(func.count(TechniqueExecution.id))
        .where(
            TechniqueExecution.user_id == current_user.id,
            TechniqueExecution.status == "confirmed",
            TechniqueExecution.created_at >= cutoff,
        )
        .scalar_subquery()
    )
    positions_total_sq = (
        select(func.count(TechniqueExecution.id))
        .where(
            TechniqueExecution.user_id == current_user.id,
            TechniqueExecution.status == "confirmed",
        )
        .scalar_subquery()
    )
    videos_30d_sq = (
        select(func.count(TrainingVideoDailyView.id))
        .where(
            TrainingVideoDailyView.user_id == current_user.id,
            TrainingVideoDailyView.completed_at >= cutoff,
        )
        .scalar_subquery()
    )
    me_row = (
        await db.execute(
            select(
                workouts_30d_sq,
                last_checkin_sq,
                positions_30d_sq,
                positions_total_sq,
                videos_30d_sq,
            )
        )
    ).one()
    workouts_last_30_days: int = me_row[0]
    last_at: datetime | None = me_row[1]
    positions_last_30_days: int = me_row[2]
    positions_total: int = me_row[3]
    videos_last_30_days: int = me_row[4]

    # ── Dias sem treinar: desde o último check-in na chamada ──
    if last_at is None:
        days_since: int | None = None
    else:
        if last_at.tzinfo is None:
            last_at = last_at.replace(tzinfo=UTC)
        today_app = now.astimezone(_APP_TZ).date()
        last_app = last_at.astimezone(_APP_TZ).date()
        days_since = (today_app - last_app).days

    avg_top10_workouts: float | None = None
    avg_top10_positions: float | None = None
    ranking: int | None = None
    total_students: int | None = None
    avg_top10_videos: float | None = None
    ranking_videos: int | None = None

    if current_user.academy_id is not None:
        # ── Treinos: média dos top 10 da academia nos últimos 30 dias ──
        per_student_workouts = (
            select(
                AttendanceRecord.user_id,
                func.count(AttendanceRecord.id).label("cnt"),
            )
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .join(User, User.id == AttendanceRecord.user_id)
            .where(
                AttendanceSession.academy_id == current_user.academy_id,
                AttendanceRecord.checked_in_at >= cutoff,
                User.role == "aluno",
            )
            .group_by(AttendanceRecord.user_id)
            .order_by(func.count(AttendanceRecord.id).desc())
            .limit(10)
            .subquery()
        )
        r = await db.execute(select(func.avg(per_student_workouts.c.cnt)))
        raw = r.scalar_one()
        if raw is not None:
            avg_top10_workouts = round(float(raw), 1)

        # ── Posições: média top 10 (30d), ranking por total e nº de alunos em 1 query ──
        per_student_positions = (
            select(
                TechniqueExecution.user_id.label("user_id"),
                func.count(TechniqueExecution.id)
                .filter(TechniqueExecution.created_at >= cutoff)
                .label("cnt_30d"),
                func.count(TechniqueExecution.id).label("cnt_total"),
            )
            .join(User, User.id == TechniqueExecution.user_id)
            .where(
                User.academy_id == current_user.academy_id,
                User.role == "aluno",
                TechniqueExecution.status == "confirmed",
            )
            .group_by(TechniqueExecution.user_id)
            .cte("per_student_positions")
        )
        # row_number (e não rank): preserva o desempate posicional do enumerate antigo.
        positions_ranked = select(
            per_student_positions.c.user_id,
            func.row_number()
            .over(order_by=per_student_positions.c.cnt_total.desc())
            .label("rn"),
        ).cte("positions_ranked")
        # Top 10 apenas entre quem tem execução nos 30 dias (semântica original).
        top10_positions = (
            select(per_student_positions.c.cnt_30d.label("cnt"))
            .where(per_student_positions.c.cnt_30d > 0)
            .order_by(per_student_positions.c.cnt_30d.desc())
            .limit(10)
            .subquery()
        )
        positions_row = (
            await db.execute(
                select(
                    select(func.avg(top10_positions.c.cnt)).scalar_subquery(),
                    select(positions_ranked.c.rn)
                    .where(positions_ranked.c.user_id == current_user.id)
                    .scalar_subquery(),
                    select(func.count()).select_from(positions_ranked).scalar_subquery(),
                    select(func.count(User.id))
                    .where(
                        User.academy_id == current_user.academy_id,
                        User.role == "aluno",
                    )
                    .scalar_subquery(),
                )
            )
        ).one()
        raw_avg_positions, user_rank, ranked_count, students_count = positions_row
        if raw_avg_positions is not None:
            avg_top10_positions = round(float(raw_avg_positions), 1)
        total_students = students_count or None
        if ranked_count:
            # Aluno sem posições confirmadas: último lugar.
            ranking = int(user_rank) if user_rank is not None else int(ranked_count) + 1

        # ── Vídeos: média top 10 e ranking nos últimos 30 dias em 1 query ──
        per_student_videos = (
            select(
                TrainingVideoDailyView.user_id.label("user_id"),
                func.count(TrainingVideoDailyView.id).label("cnt"),
            )
            .join(User, User.id == TrainingVideoDailyView.user_id)
            .where(
                User.academy_id == current_user.academy_id,
                User.role == "aluno",
                TrainingVideoDailyView.completed_at >= cutoff,
            )
            .group_by(TrainingVideoDailyView.user_id)
            .cte("per_student_videos")
        )
        videos_ranked = select(
            per_student_videos.c.user_id,
            func.row_number().over(order_by=per_student_videos.c.cnt.desc()).label("rn"),
        ).cte("videos_ranked")
        top10_videos = (
            select(per_student_videos.c.cnt.label("cnt"))
            .order_by(per_student_videos.c.cnt.desc())
            .limit(10)
            .subquery()
        )
        videos_row = (
            await db.execute(
                select(
                    select(func.avg(top10_videos.c.cnt)).scalar_subquery(),
                    select(videos_ranked.c.rn)
                    .where(videos_ranked.c.user_id == current_user.id)
                    .scalar_subquery(),
                    select(func.count()).select_from(videos_ranked).scalar_subquery(),
                )
            )
        ).one()
        raw_avg_videos, video_rank, videos_count = videos_row
        if raw_avg_videos is not None:
            avg_top10_videos = round(float(raw_avg_videos), 1)
        # Aluno sem vídeos assistidos: último entre quem assistiu + 1.
        ranking_videos = int(video_rank) if video_rank is not None else int(videos_count) + 1

    stats = TrainingStatsRead(
        workouts_last_30_days=workouts_last_30_days,
        days_since_last_workout=days_since,
        positions_last_30_days=positions_last_30_days,
        positions_total=positions_total,
        avg_top10_workouts_last_30_days=avg_top10_workouts,
        avg_top10_positions_last_30_days=avg_top10_positions,
        ranking_positions_total=ranking,
        ranking_positions_total_out_of=total_students,
        videos_last_30_days=videos_last_30_days,
        avg_top10_videos_last_30_days=avg_top10_videos,
        ranking_videos_last_30_days=ranking_videos,
    )
    await app_cache.set(cache_key, stats.model_dump(), ttl=TRAINING_STATS_TTL_SEC)
    return stats
