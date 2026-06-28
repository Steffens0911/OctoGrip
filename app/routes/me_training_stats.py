"""Estatísticas de treino do aluno autenticado (últimos 30 dias + total + rankings)."""

from __future__ import annotations

from collections import defaultdict
from datetime import UTC, date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

_APP_TZ = ZoneInfo("America/Sao_Paulo")

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_time import today_in_app_tz
from app.core.auth_deps import get_current_user
from app.core.cache import app_cache
from app.database import get_db
from app.models import AttendanceRecord, AttendanceSession, User
from app.models.technique_execution import TechniqueExecution
from app.models.training_video import TrainingVideoDailyView
from app.models.user_login_day import UserLoginDay
from app.models.user_trophy_earned import UserTrophyEarned
from app.services.execution_service import batch_total_points_for_users
from app.services.login_streak_service import login_streak_from_distinct_days
from app.services.training_stats_cache import (
    TRAINING_STATS_TTL_SEC,
    training_stats_cache_key,
)

router = APIRouter()


def _best_streak_from_distinct_days(login_days: list[date]) -> int:
    """Comprimento da maior sequência consecutiva de dias na lista (recorde pessoal)."""
    if not login_days:
        return 0
    days = sorted(set(login_days))
    best = current = 1
    for i in range(1, len(days)):
        if days[i] == days[i - 1] + timedelta(days=1):
            current += 1
            if current > best:
                best = current
        else:
            current = 1
    return best


class TrainingStatsRead(BaseModel):
    # ── existentes ──
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
    # ── novos ──
    videos_total: int
    ranking_videos_total: int | None
    ranking_videos_total_out_of: int | None
    trophies_total: int
    total_xp: int
    ranking_xp: int | None
    ranking_xp_out_of: int | None
    login_streak_current: int
    login_streak_best: int
    ranking_login_streak: int | None
    ranking_login_streak_out_of: int | None
    punctuality_streak: int
    punctuality_streak_best: int
    ranking_punctuality: int | None
    ranking_punctuality_out_of: int | None


@router.get("/training_stats", response_model=TrainingStatsRead)
async def my_training_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Estatísticas completas do aluno: presenças, técnicas, vídeos, troféus, XP e streaks com rankings."""
    cache_key = training_stats_cache_key(current_user.id)
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return TrainingStatsRead(**cached)

    now = datetime.now(UTC)
    cutoff = now - timedelta(days=30)
    today = today_in_app_tz()

    # ── Métricas do próprio aluno (1 query) ──
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
    videos_total_sq = (
        select(func.count(TrainingVideoDailyView.id))
        .where(TrainingVideoDailyView.user_id == current_user.id)
        .scalar_subquery()
    )
    trophies_total_sq = (
        select(func.count(UserTrophyEarned.id)).where(UserTrophyEarned.user_id == current_user.id).scalar_subquery()
    )
    me_row = (
        await db.execute(
            select(
                workouts_30d_sq,
                last_checkin_sq,
                positions_30d_sq,
                positions_total_sq,
                videos_30d_sq,
                videos_total_sq,
                trophies_total_sq,
            )
        )
    ).one()
    workouts_last_30_days: int = me_row[0]
    last_at: datetime | None = me_row[1]
    positions_last_30_days: int = me_row[2]
    positions_total: int = me_row[3]
    videos_last_30_days: int = me_row[4]
    videos_total: int = me_row[5]
    trophies_total: int = me_row[6]

    # ── Dias sem treinar ──
    if last_at is None:
        days_since: int | None = None
    else:
        if last_at.tzinfo is None:
            last_at = last_at.replace(tzinfo=UTC)
        today_app = now.astimezone(_APP_TZ).date()
        last_app = last_at.astimezone(_APP_TZ).date()
        days_since = (today_app - last_app).days

    # ── Login streak do próprio aluno ──
    login_days_result = await db.execute(
        select(UserLoginDay.login_day)
        .where(UserLoginDay.user_id == current_user.id)
        .order_by(UserLoginDay.login_day.desc())
        .limit(400)
    )
    my_login_days = list(login_days_result.scalars().all())
    login_streak_current = login_streak_from_distinct_days(my_login_days, today)
    login_streak_best = _best_streak_from_distinct_days(my_login_days)

    # ── Pontualidade (armazenada no User) ──
    punctuality_streak = current_user.punctuality_streak or 0
    punctuality_streak_best = current_user.punctuality_streak_best or 0

    # Inicializar rankings (None quando sem academia)
    avg_top10_workouts: float | None = None
    avg_top10_positions: float | None = None
    ranking: int | None = None
    total_students: int | None = None
    avg_top10_videos: float | None = None
    ranking_videos: int | None = None
    ranking_videos_total: int | None = None
    ranking_videos_total_out_of: int | None = None
    total_xp = 0
    ranking_xp: int | None = None
    ranking_xp_out_of: int | None = None
    ranking_login_streak: int | None = None
    ranking_login_streak_out_of: int | None = None
    ranking_punctuality: int | None = None
    ranking_punctuality_out_of: int | None = None

    if current_user.academy_id is not None:
        # ── Treinos: média top 10 (30d) ──
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

        # ── Posições: médias + ranking total ──
        per_student_positions = (
            select(
                TechniqueExecution.user_id.label("user_id"),
                func.count(TechniqueExecution.id).filter(TechniqueExecution.created_at >= cutoff).label("cnt_30d"),
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
        positions_ranked = select(
            per_student_positions.c.user_id,
            func.row_number().over(order_by=per_student_positions.c.cnt_total.desc()).label("rn"),
        ).cte("positions_ranked")
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
            ranking = int(user_rank) if user_rank is not None else int(ranked_count) + 1

        # ── Vídeos: 30d + all-time, ambos com ranking, em 1 query ──
        per_student_videos = (
            select(
                TrainingVideoDailyView.user_id.label("user_id"),
                func.count(TrainingVideoDailyView.id)
                .filter(TrainingVideoDailyView.completed_at >= cutoff)
                .label("cnt_30d"),
                func.count(TrainingVideoDailyView.id).label("cnt_total"),
            )
            .join(User, User.id == TrainingVideoDailyView.user_id)
            .where(
                User.academy_id == current_user.academy_id,
                User.role == "aluno",
            )
            .group_by(TrainingVideoDailyView.user_id)
            .cte("per_student_videos")
        )
        videos_ranked_30d = select(
            per_student_videos.c.user_id,
            func.row_number().over(order_by=per_student_videos.c.cnt_30d.desc()).label("rn"),
        ).cte("videos_ranked_30d")
        videos_ranked_total = select(
            per_student_videos.c.user_id,
            func.row_number().over(order_by=per_student_videos.c.cnt_total.desc()).label("rn"),
        ).cte("videos_ranked_total")
        top10_videos = (
            select(per_student_videos.c.cnt_30d.label("cnt"))
            .order_by(per_student_videos.c.cnt_30d.desc())
            .limit(10)
            .subquery()
        )
        videos_row = (
            await db.execute(
                select(
                    select(func.avg(top10_videos.c.cnt)).scalar_subquery(),
                    select(videos_ranked_30d.c.rn)
                    .where(videos_ranked_30d.c.user_id == current_user.id)
                    .scalar_subquery(),
                    select(func.count()).select_from(videos_ranked_30d).scalar_subquery(),
                    select(videos_ranked_total.c.rn)
                    .where(videos_ranked_total.c.user_id == current_user.id)
                    .scalar_subquery(),
                    select(func.count()).select_from(videos_ranked_total).scalar_subquery(),
                )
            )
        ).one()
        raw_avg_videos, video_rank_30d, videos_count_30d, video_rank_total, videos_count_total = videos_row
        if raw_avg_videos is not None:
            avg_top10_videos = round(float(raw_avg_videos), 1)
        ranking_videos = int(video_rank_30d) if video_rank_30d is not None else int(videos_count_30d) + 1
        ranking_videos_total = int(video_rank_total) if video_rank_total is not None else int(videos_count_total) + 1
        ranking_videos_total_out_of = total_students

        # ── XP total + ranking (Python, reusa batch helper) ──
        all_student_ids: list[UUID] = list(
            (
                await db.execute(
                    select(User.id).where(
                        User.academy_id == current_user.academy_id,
                        User.role == "aluno",
                    )
                )
            )
            .scalars()
            .all()
        )
        if all_student_ids:
            xp_map = await batch_total_points_for_users(db, all_student_ids)
            total_xp = xp_map.get(current_user.id, 0)
            ranking_xp = sum(1 for v in xp_map.values() if v > total_xp) + 1
            ranking_xp_out_of = len(all_student_ids)

            # ── Login streak: ranking calculado para todos os alunos em Python ──
            all_login_days_result = await db.execute(
                select(UserLoginDay.user_id, UserLoginDay.login_day)
                .join(User, User.id == UserLoginDay.user_id)
                .where(
                    User.academy_id == current_user.academy_id,
                    User.role == "aluno",
                )
            )
            login_days_by_user: dict[UUID, list[date]] = defaultdict(list)
            for uid, day in all_login_days_result.all():
                login_days_by_user[uid].append(day)

            streak_map: dict[UUID, int] = {
                uid: login_streak_from_distinct_days(login_days_by_user.get(uid, []), today) for uid in all_student_ids
            }
            my_streak_val = streak_map.get(current_user.id, login_streak_current)
            ranking_login_streak = sum(1 for v in streak_map.values() if v > my_streak_val) + 1
            ranking_login_streak_out_of = len(all_student_ids)

        # ── Pontualidade: ranking via SQL ──
        punct_subq = (
            select(
                User.id.label("user_id"),
                func.row_number().over(order_by=User.punctuality_streak.desc()).label("rn"),
                func.count(User.id).over().label("total"),
            )
            .where(
                User.academy_id == current_user.academy_id,
                User.role == "aluno",
            )
            .subquery()
        )
        punct_row = (
            await db.execute(select(punct_subq.c.rn, punct_subq.c.total).where(punct_subq.c.user_id == current_user.id))
        ).one_or_none()
        if punct_row:
            ranking_punctuality = int(punct_row[0])
            ranking_punctuality_out_of = int(punct_row[1])

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
        videos_total=videos_total,
        ranking_videos_total=ranking_videos_total,
        ranking_videos_total_out_of=ranking_videos_total_out_of,
        trophies_total=trophies_total,
        total_xp=total_xp,
        ranking_xp=ranking_xp,
        ranking_xp_out_of=ranking_xp_out_of,
        login_streak_current=login_streak_current,
        login_streak_best=login_streak_best,
        ranking_login_streak=ranking_login_streak,
        ranking_login_streak_out_of=ranking_login_streak_out_of,
        punctuality_streak=punctuality_streak,
        punctuality_streak_best=punctuality_streak_best,
        ranking_punctuality=ranking_punctuality,
        ranking_punctuality_out_of=ranking_punctuality_out_of,
    )
    await app_cache.set(cache_key, stats.model_dump(), ttl=TRAINING_STATS_TTL_SEC)
    return stats
