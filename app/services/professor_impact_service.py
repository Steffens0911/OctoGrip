from __future__ import annotations

import uuid
from datetime import date, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.app_time import today_in_app_tz, utc_now
from app.models import AttendanceRecord, AttendanceSession, Technique, TechniqueExecution, User
from app.models.mission import Mission
from app.models.mission_usage import MissionUsage
from app.models.training_video import TrainingVideoDailyView
from app.schemas.professor_impact import (
    AtRiskStudent,
    DailyVideoView,
    ExecutionDetail,
    ProfessorImpactResponse,
    TechniqueImpact,
)
from app.utils.iso_week import (
    date_range_for_iso_week,
    iso_week_key_for_date,
    utc_datetime_bounds_for_iso_week,
)

_AT_RISK_ALERT_DAYS = 14
_AT_RISK_WARNING_DAYS = 7
_CONFIRMED = "confirmed"


async def get_professor_impact(
    db: AsyncSession,
    academy_id: uuid.UUID,
    reference_date: date | None = None,
) -> ProfessorImpactResponse:
    ref = reference_date or today_in_app_tz()
    iso_year, iso_week = iso_week_key_for_date(ref)
    week_start_utc, week_end_utc = utc_datetime_bounds_for_iso_week(iso_year, iso_week)
    monday, sunday = date_range_for_iso_week(iso_year, iso_week)

    prev_ref = ref - timedelta(days=7)
    prev_year, prev_week = iso_week_key_for_date(prev_ref)
    prev_start_utc, prev_end_utc = utc_datetime_bounds_for_iso_week(prev_year, prev_week)

    # Total de alunos ativos na academia
    total_students: int = (
        await db.scalar(
            select(func.count(User.id)).where(
                User.academy_id == academy_id,
                User.role == "aluno",
                User.account_frozen == False,  # noqa: E712
            )
        )
        or 0
    )

    # Alunos que tiveram pelo menos 1 execução confirmada na semana
    students_reached_this = await _count_distinct_students_reached(db, academy_id, week_start_utc, week_end_utc)
    students_reached_prev = await _count_distinct_students_reached(db, academy_id, prev_start_utc, prev_end_utc)

    completion_rate = (students_reached_this / total_students * 100.0) if total_students > 0 else 0.0
    prev_rate = (students_reached_prev / total_students * 100.0) if total_students > 0 else 0.0
    completion_rate_delta: float | None = round(completion_rate - prev_rate, 1) if total_students > 0 else None

    # Execuções confirmadas por técnica na semana (agregado)
    technique_rows = (
        await db.execute(
            select(
                Technique.id.label("technique_id"),
                Technique.name,
                func.count(func.distinct(TechniqueExecution.user_id)).label("students_completed"),
                func.count(TechniqueExecution.id).label("executions_count"),
            )
            .join(User, TechniqueExecution.user_id == User.id)
            .join(Technique, TechniqueExecution.technique_id == Technique.id)
            .where(
                User.academy_id == academy_id,
                User.role == "aluno",
                TechniqueExecution.status == _CONFIRMED,
                TechniqueExecution.confirmed_at >= week_start_utc,
                TechniqueExecution.confirmed_at < week_end_utc,
                TechniqueExecution.technique_id.is_not(None),
            )
            .group_by(Technique.id, Technique.name)
            .order_by(func.count(func.distinct(TechniqueExecution.user_id)).desc())
        )
    ).all()

    # Detalhes individuais (executor → oponente) por técnica na semana
    OpponentUser = aliased(User, name="opponent_user")
    detail_rows = (
        await db.execute(
            select(
                TechniqueExecution.technique_id,
                User.name.label("executor_name"),
                OpponentUser.name.label("opponent_name"),
            )
            .join(User, TechniqueExecution.user_id == User.id)
            .outerjoin(OpponentUser, TechniqueExecution.opponent_id == OpponentUser.id)
            .where(
                User.academy_id == academy_id,
                User.role == "aluno",
                TechniqueExecution.status == _CONFIRMED,
                TechniqueExecution.confirmed_at >= week_start_utc,
                TechniqueExecution.confirmed_at < week_end_utc,
                TechniqueExecution.technique_id.is_not(None),
            )
            .order_by(TechniqueExecution.confirmed_at.desc())
        )
    ).all()

    # Agrupa detalhes por technique_id
    details_by_technique: dict[uuid.UUID, list[ExecutionDetail]] = {}
    for d in detail_rows:
        details_by_technique.setdefault(d.technique_id, []).append(
            ExecutionDetail(executor_name=d.executor_name or "?", opponent_name=d.opponent_name)
        )

    techniques = [
        TechniqueImpact(
            technique_name=row.name,
            students_completed=row.students_completed,
            total_students=total_students,
            completion_pct=round(row.students_completed / total_students * 100.0, 1) if total_students > 0 else 0.0,
            missions_count=row.executions_count,
            executions=details_by_technique.get(row.technique_id, []),
        )
        for row in technique_rows
    ]

    # Alunos sem presença na chamada nos últimos 7+ dias
    now_utc = utc_now()
    cutoff = now_utc - timedelta(days=_AT_RISK_WARNING_DAYS)

    # Última presença confirmada por aluno nesta academia
    last_checkin_subq = (
        select(
            AttendanceRecord.user_id,
            func.max(AttendanceRecord.checked_in_at).label("last_checkin"),
        )
        .join(AttendanceSession, AttendanceRecord.session_id == AttendanceSession.id)
        .where(AttendanceSession.academy_id == academy_id)
        .group_by(AttendanceRecord.user_id)
        .subquery()
    )

    risk_rows = (
        await db.execute(
            select(
                User.id,
                User.name,
                last_checkin_subq.c.last_checkin,
            )
            .outerjoin(last_checkin_subq, User.id == last_checkin_subq.c.user_id)
            .where(
                User.academy_id == academy_id,
                User.role == "aluno",
                User.account_frozen == False,  # noqa: E712
                or_(
                    last_checkin_subq.c.last_checkin < cutoff,
                    last_checkin_subq.c.last_checkin.is_(None),
                ),
            )
            .order_by(last_checkin_subq.c.last_checkin.asc().nulls_first())
        )
    ).all()

    import datetime as _dt

    at_risk = []
    for row in risk_rows:
        if row.last_checkin is None:
            days = 999
        else:
            last = row.last_checkin
            if last.tzinfo is None:
                last = last.replace(tzinfo=_dt.UTC)
            days = (now_utc - last).days
        level = "alert" if days >= _AT_RISK_ALERT_DAYS else "warning"
        at_risk.append(
            AtRiskStudent(
                id=str(row.id),
                name=row.name or "Aluno sem nome",
                days_inactive=min(days, 999),
                risk_level=level,
            )
        )

    # Visualizações diárias de vídeos na semana
    video_rows = (
        await db.execute(
            select(
                TrainingVideoDailyView.view_date,
                func.count(TrainingVideoDailyView.id).label("views_count"),
            )
            .join(User, TrainingVideoDailyView.user_id == User.id)
            .where(
                User.academy_id == academy_id,
                User.role == "aluno",
                TrainingVideoDailyView.view_date >= monday,
                TrainingVideoDailyView.view_date <= sunday,
            )
            .group_by(TrainingVideoDailyView.view_date)
            .order_by(TrainingVideoDailyView.view_date)
        )
    ).all()

    daily_video_views = [DailyVideoView(view_date=row.view_date, views_count=row.views_count) for row in video_rows]

    # Totais históricos
    total_missions_in_academy: int = (
        await db.scalar(
            select(func.count(Mission.id)).where(
                Mission.academy_id == academy_id,
                Mission.is_active == True,  # noqa: E712
            )
        )
        or 0
    )

    total_completions_all_time: int = (
        await db.scalar(
            select(func.count(MissionUsage.id))
            .join(User, MissionUsage.user_id == User.id)
            .join(Mission, MissionUsage.mission_id == Mission.id)
            .where(
                User.academy_id == academy_id,
                User.role == "aluno",
                Mission.academy_id == academy_id,
            )
        )
        or 0
    )

    return ProfessorImpactResponse(
        week_start=monday,
        week_end=sunday,
        students_reached=students_reached_this,
        total_students=total_students,
        completion_rate=round(completion_rate, 1),
        completion_rate_delta=completion_rate_delta,
        techniques=techniques,
        at_risk_students=at_risk,
        total_missions_in_academy=total_missions_in_academy,
        total_completions_all_time=total_completions_all_time,
        daily_video_views=daily_video_views,
    )


async def _count_distinct_students_reached(
    db: AsyncSession,
    academy_id: uuid.UUID,
    start_utc,
    end_utc,
) -> int:
    subq = (
        select(func.distinct(TechniqueExecution.user_id))
        .join(User, TechniqueExecution.user_id == User.id)
        .where(
            User.academy_id == academy_id,
            User.role == "aluno",
            TechniqueExecution.status == _CONFIRMED,
            TechniqueExecution.confirmed_at >= start_utc,
            TechniqueExecution.confirmed_at < end_utc,
        )
        .subquery()
    )
    return await db.scalar(select(func.count()).select_from(subq)) or 0
