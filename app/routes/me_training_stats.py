"""Estatísticas de treino do aluno autenticado (últimos 30 dias + total)."""
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

_APP_TZ = ZoneInfo("America/Sao_Paulo")

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.database import get_db
from app.models import AttendanceRecord, AttendanceSession, User
from app.models.technique_execution import TechniqueExecution

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


@router.get("/training_stats", response_model=TrainingStatsRead)
async def my_training_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Estatísticas de treino do aluno: presenças nas chamadas e posições confirmadas."""
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=30)

    # ── Treinos: presenças registradas via chamada nos últimos 30 dias ──
    result_workouts = await db.execute(
        select(func.count(AttendanceRecord.id))
        .select_from(AttendanceRecord)
        .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
        .where(
            AttendanceRecord.user_id == current_user.id,
            AttendanceRecord.checked_in_at >= cutoff,
        )
    )
    workouts_last_30_days: int = result_workouts.scalar_one()

    # ── Dias sem treinar: desde o último check-in na chamada ──
    result_last = await db.execute(
        select(func.max(AttendanceRecord.checked_in_at)).where(
            AttendanceRecord.user_id == current_user.id,
        )
    )
    last_at: datetime | None = result_last.scalar_one()

    if last_at is None:
        days_since: int | None = None
    else:
        if last_at.tzinfo is None:
            last_at = last_at.replace(tzinfo=timezone.utc)
        today_app = now.astimezone(_APP_TZ).date()
        last_app = last_at.astimezone(_APP_TZ).date()
        days_since = (today_app - last_app).days

    # ── Posições: execuções confirmadas pelo adversário ──
    base_confirmed = select(TechniqueExecution).where(
        TechniqueExecution.user_id == current_user.id,
        TechniqueExecution.status == "confirmed",
    )

    result_month = await db.execute(
        select(func.count()).select_from(
            base_confirmed.where(TechniqueExecution.created_at >= cutoff).subquery()
        )
    )
    positions_last_30_days: int = result_month.scalar_one()

    result_total = await db.execute(
        select(func.count()).select_from(base_confirmed.subquery())
    )
    positions_total: int = result_total.scalar_one()

    # ── Média dos top 10 alunos da mesma academia (treinos nos últimos 30 dias) ──
    avg_top10_workouts: float | None = None
    avg_top10_positions: float | None = None

    if current_user.academy_id is not None:
        # Top 10 em presenças (chamada) nos últimos 30 dias
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

        # Top 10 em posições confirmadas nos últimos 30 dias
        per_student_positions = (
            select(
                TechniqueExecution.user_id,
                func.count(TechniqueExecution.id).label("cnt"),
            )
            .join(User, User.id == TechniqueExecution.user_id)
            .where(
                User.academy_id == current_user.academy_id,
                TechniqueExecution.status == "confirmed",
                TechniqueExecution.created_at >= cutoff,
                User.role == "aluno",
            )
            .group_by(TechniqueExecution.user_id)
            .order_by(func.count(TechniqueExecution.id).desc())
            .limit(10)
            .subquery()
        )
        r2 = await db.execute(select(func.avg(per_student_positions.c.cnt)))
        raw2 = r2.scalar_one()
        if raw2 is not None:
            avg_top10_positions = round(float(raw2), 1)

        # Ranking do aluno por posições totais na academia
        all_students = (
            select(
                TechniqueExecution.user_id,
                func.count(TechniqueExecution.id).label("cnt"),
            )
            .join(User, User.id == TechniqueExecution.user_id)
            .where(
                User.academy_id == current_user.academy_id,
                TechniqueExecution.status == "confirmed",
                User.role == "aluno",
            )
            .group_by(TechniqueExecution.user_id)
            .order_by(func.count(TechniqueExecution.id).desc())
            .subquery()
        )
        result_ranking = await db.execute(select(all_students))
        rows = result_ranking.fetchall()
        ranking: int | None = None

        # Total real de alunos da academia (independente de terem posições)
        result_total_students = await db.execute(
            select(func.count(User.id)).where(
                User.academy_id == current_user.academy_id,
                User.role == "aluno",
            )
        )
        total_students: int | None = result_total_students.scalar_one() or None

        if rows:
            for pos, row in enumerate(rows, start=1):
                if row.user_id == current_user.id:
                    ranking = pos
                    break
            if ranking is None:
                # Aluno sem posições confirmadas: último lugar
                ranking = len(rows) + 1

    else:
        ranking = None
        total_students = None

    return TrainingStatsRead(
        workouts_last_30_days=workouts_last_30_days,
        days_since_last_workout=days_since,
        positions_last_30_days=positions_last_30_days,
        positions_total=positions_total,
        avg_top10_workouts_last_30_days=avg_top10_workouts,
        avg_top10_positions_last_30_days=avg_top10_positions,
        ranking_positions_total=ranking,
        ranking_positions_total_out_of=total_students,
    )
