import logging
from datetime import date, datetime, time, timedelta, timezone
import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import LessonProgress, MissionUsage, User, UserLoginDay

logger = logging.getLogger(__name__)

_PANEL_ROLES = ("administrador", "gerente_academia", "professor", "supervisor")
# Relatório semanal de logins: painel + alunos (mesma fonte user_login_days).
_WEEKLY_LOGIN_REPORT_ROLES = (*_PANEL_ROLES, "aluno")


def _build_usage_metrics_result(
    *,
    total_completions: int,
    completions_last_7_days: int,
    unique_users_completed: int,
    before_training_count: int,
    after_training_count: int,
) -> dict:
    total_usage = before_training_count + after_training_count
    before_percent = (
        round((before_training_count / total_usage * 100.0), 1) if total_usage > 0 else 0.0
    )
    result = {
        "total_completions": total_completions,
        "completions_last_7_days": completions_last_7_days,
        "unique_users_completed": unique_users_completed,
        "before_training_count": before_training_count,
        "after_training_count": after_training_count,
        "before_training_percent": before_percent,
    }
    return result


async def get_usage_metrics(db: AsyncSession) -> dict:
    """
    Retorna métricas de uso globais (LessonProgress) e retenção (MissionUsage, PB-02).
    """
    total = await db.scalar(select(func.count(LessonProgress.id))) or 0

    since_7_days = datetime.now(timezone.utc) - timedelta(days=7)
    last_7 = await db.scalar(
        select(func.count(LessonProgress.id)).where(LessonProgress.completed_at >= since_7_days)
    ) or 0

    unique_users = await db.scalar(select(func.count(func.distinct(LessonProgress.user_id)))) or 0

    before = await db.scalar(
        select(func.count(MissionUsage.id)).where(MissionUsage.usage_type == "before_training")
    ) or 0
    after = await db.scalar(
        select(func.count(MissionUsage.id)).where(MissionUsage.usage_type == "after_training")
    ) or 0

    result = _build_usage_metrics_result(
        total_completions=total,
        completions_last_7_days=last_7,
        unique_users_completed=unique_users,
        before_training_count=before,
        after_training_count=after,
    )
    logger.info("get_usage_metrics", extra=result)
    return result


async def get_usage_metrics_for_academy(db: AsyncSession, academy_id: uuid.UUID) -> dict:
    """
    Retorna métricas de uso filtradas por academy_id (para gestor local/global).
    """
    # Filtro por academia via relação com User
    since_7_days = datetime.now(timezone.utc) - timedelta(days=7)

    total = await db.scalar(
        select(func.count(LessonProgress.id))
        .join(User, LessonProgress.user_id == User.id)
        .where(User.academy_id == academy_id)
    ) or 0

    last_7 = await db.scalar(
        select(func.count(LessonProgress.id))
        .join(User, LessonProgress.user_id == User.id)
        .where(
            User.academy_id == academy_id,
            LessonProgress.completed_at >= since_7_days,
        )
    ) or 0

    unique_users = await db.scalar(
        select(func.count(func.distinct(LessonProgress.user_id)))
        .join(User, LessonProgress.user_id == User.id)
        .where(User.academy_id == academy_id)
    ) or 0

    before = await db.scalar(
        select(func.count(MissionUsage.id))
        .join(User, MissionUsage.user_id == User.id)
        .where(
            User.academy_id == academy_id,
            MissionUsage.usage_type == "before_training",
        )
    ) or 0

    after = await db.scalar(
        select(func.count(MissionUsage.id))
        .join(User, MissionUsage.user_id == User.id)
        .where(
            User.academy_id == academy_id,
            MissionUsage.usage_type == "after_training",
        )
    ) or 0

    result = _build_usage_metrics_result(
        total_completions=total,
        completions_last_7_days=last_7,
        unique_users_completed=unique_users,
        before_training_count=before,
        after_training_count=after,
    )
    logger.info(
        "get_usage_metrics_for_academy",
        extra={**result, "academy_id": str(academy_id)},
    )
    return result


async def _compute_engagement_for_period(
    db: AsyncSession,
    *,
    start: date,
    end: date,
    academy_id: uuid.UUID | None,
) -> dict:
    """Calcula % de alunos ativos em um período (start..end)."""
    # Normalizar para datetimes com timezone para comparação com last_login_at
    start_dt = datetime.combine(start, time.min, tzinfo=timezone.utc)
    end_dt = datetime.combine(end, time.max, tzinfo=timezone.utc)

    # Total de alunos (role=aluno), opcionalmente filtrando por academia
    total_query = select(func.count(User.id)).where(User.role == "aluno")
    if academy_id is not None:
        total_query = total_query.where(User.academy_id == academy_id)

    total_students = await db.scalar(total_query) or 0

    # Alunos ativos: pelo menos 1 login no período (last_login_at dentro do range)
    active_query = select(func.count(User.id)).where(
        User.role == "aluno",
        User.last_login_at.is_not(None),
        User.last_login_at >= start_dt,
        User.last_login_at <= end_dt,
    )
    if academy_id is not None:
        active_query = active_query.where(User.academy_id == academy_id)

    active_students = await db.scalar(active_query) or 0

    active_rate = (
        round(active_students / total_students * 100.0, 1) if total_students > 0 else 0.0
    )

    return {
        "start_date": start,
        "end_date": end,
        "total_students": total_students,
        "active_students": active_students,
        "active_rate": active_rate,
    }


async def get_engagement_report(
    db: AsyncSession,
    *,
    reference_date: date,
    academy_id: uuid.UUID | None,
) -> dict:
    """
    Retorna relatório de engajamento semanal e mensal (% de alunos ativos).

    - Se academy_id for informado: visão local (apenas aquela academia).
    - Se academy_id for null: visão geral (todas as academias).

    Definição de aluno ativo:
    - Pelo menos um login (last_login_at) dentro do período considerado.
    - Semana: últimos 7 dias em relação à reference_date (janela móvel).
    - Mês: do primeiro dia do mês até a reference_date.
    """
    # Semana: últimos 7 dias em relação à data de referência (janela móvel)
    week_end = reference_date
    week_start = reference_date - timedelta(days=6)

    # Mês: 1º dia do mês até a data de referência
    month_start = reference_date.replace(day=1)
    month_end = reference_date

    weekly = await _compute_engagement_for_period(
        db,
        start=week_start,
        end=week_end,
        academy_id=academy_id,
    )
    monthly = await _compute_engagement_for_period(
        db,
        start=month_start,
        end=month_end,
        academy_id=academy_id,
    )

    result = {
        "academy_id": str(academy_id) if academy_id is not None else None,
        "weekly": weekly,
        "monthly": monthly,
    }
    logger.info(
        "get_engagement_report",
        extra={
            "academy_id": result["academy_id"],
            "weekly_active_rate": weekly["active_rate"],
            "monthly_active_rate": monthly["active_rate"],
        },
    )
    return result


async def get_active_students_report(
    db: AsyncSession,
    *,
    reference_date: date,
    academy_id: uuid.UUID | None,
) -> dict:
    """
    Retorna lista de alunos ativos (logaram pelo menos uma vez) na janela móvel de 7 dias.

    - Usa a mesma definição de período semanal do relatório de engajamento.
    """
    window_end = reference_date
    window_start = reference_date - timedelta(days=6)

    # Resumo numérico (reaproveita a mesma lógica de engajamento)
    summary = await _compute_engagement_for_period(
        db,
        start=window_start,
        end=window_end,
        academy_id=academy_id,
    )

    start_dt = datetime.combine(window_start, time.min, tzinfo=timezone.utc)
    end_dt = datetime.combine(window_end, time.max, tzinfo=timezone.utc)

    users_query = (
        select(User)
        .where(
            User.role == "aluno",
            User.last_login_at.is_not(None),
            User.last_login_at >= start_dt,
            User.last_login_at <= end_dt,
        )
        .order_by(User.email)
        .options(selectinload(User.academy))
    )
    if academy_id is not None:
        users_query = users_query.where(User.academy_id == academy_id)

    users = (await db.execute(users_query)).scalars().all()

    students = [
        {
            "id": str(u.id),
            "name": u.name,
            "email": u.email,
            "academy_id": str(u.academy_id) if u.academy_id is not None else None,
            "academy_name": u.academy.name if getattr(u, "academy", None) else None,
            "graduation": u.graduation,
            "last_login_at": u.last_login_at,
        }
        for u in users
    ]

    result = {
        "academy_id": str(academy_id) if academy_id is not None else None,
        "start_date": summary["start_date"],
        "end_date": summary["end_date"],
        "total_students": summary["total_students"],
        "active_students": summary["active_students"],
        "active_rate": summary["active_rate"],
        "students": students,
    }
    logger.info(
        "get_active_students_report",
        extra={
            "academy_id": result["academy_id"],
            "active_students": result["active_students"],
            "active_rate": result["active_rate"],
        },
    )
    return result


async def get_weekly_panel_logins_report(
    db: AsyncSession,
    *,
    reference_date: date,
    academy_id: uuid.UUID | None,
) -> dict:
    """
    Relatório semanal (ISO) de logins (user_login_days).

    Regras:
    - Roles elegíveis: administrador, gerente_academia, professor, supervisor e aluno.
    - Escopo por academia: apenas usuários com User.academy_id == academy_id.
      (admins globais sem academy_id aparecem somente na visão global).
    - Escopo global: todos os usuários elegíveis.
    """
    iso_year, iso_week, _ = reference_date.isocalendar()
    monday = datetime.fromisocalendar(iso_year, iso_week, 1).date()
    week_start = monday
    week_end = monday + timedelta(days=6)

    eligible_users_query = select(User).where(
        User.role.in_(_WEEKLY_LOGIN_REPORT_ROLES)
    ).order_by(User.email)
    if academy_id is not None:
        eligible_users_query = eligible_users_query.where(User.academy_id == academy_id)
    eligible_users = (await db.execute(eligible_users_query)).scalars().all()
    if not eligible_users:
        return {
            "academy_id": str(academy_id) if academy_id is not None else None,
            "week_start": week_start,
            "week_end": week_end,
            "eligible_users_count": 0,
            "users_logged_at_least_once": 0,
            "users": [],
        }

    eligible_user_ids = [u.id for u in eligible_users]
    login_rows = (
        await db.execute(
            select(UserLoginDay.user_id, UserLoginDay.login_day)
            .where(
                UserLoginDay.user_id.in_(eligible_user_ids),
                UserLoginDay.login_day >= week_start,
                UserLoginDay.login_day <= week_end,
            )
            .order_by(UserLoginDay.login_day.asc())
        )
    ).all()

    login_days_by_user: dict[uuid.UUID, list[date]] = {}
    for user_id, login_day in login_rows:
        login_days_by_user.setdefault(user_id, []).append(login_day)

    users = []
    for u in eligible_users:
        days = login_days_by_user.get(u.id, [])
        if not days:
            continue
        users.append(
            {
                "user_id": str(u.id),
                "name": u.name,
                "email": u.email,
                "role": u.role,
                "academy_id": str(u.academy_id) if u.academy_id is not None else None,
                "distinct_login_days_in_week": len(days),
                "login_days": days,
            }
        )

    users.sort(
        key=lambda item: (
            -item["distinct_login_days_in_week"],
            (item.get("name") or item["email"]).lower(),
        )
    )

    result = {
        "academy_id": str(academy_id) if academy_id is not None else None,
        "week_start": week_start,
        "week_end": week_end,
        "eligible_users_count": len(eligible_users),
        "users_logged_at_least_once": len(users),
        "users": users,
    }
    logger.info(
        "get_weekly_panel_logins_report",
        extra={
            "academy_id": result["academy_id"],
            "week_start": str(week_start),
            "week_end": str(week_end),
            "eligible_users_count": result["eligible_users_count"],
            "users_logged_at_least_once": result["users_logged_at_least_once"],
        },
    )
    return result
