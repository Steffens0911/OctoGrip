import logging
import uuid
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.app_time import (
    combine_local_date_end_utc,
    combine_local_date_start_utc,
    today_in_app_tz,
)
from app.core.cache import app_cache
from app.models import (
    AttendanceRecord,
    AttendanceSession,
    LessonProgress,
    MissionUsage,
    TechniqueExecution,
    User,
    UserLoginDay,
)

logger = logging.getLogger(__name__)

_METRICS_TTL_SEC = 120
_METRICS_PREFIX = "metrics_report:"

_PANEL_ROLES = ("administrador", "gerente_academia", "professor", "supervisor")
# Relatório semanal de logins: painel + alunos (mesma fonte user_login_days).
_WEEKLY_LOGIN_REPORT_ROLES = (*_PANEL_ROLES, "aluno")


async def _metrics_cache_key(suffix: str) -> str:
    return await app_cache.versioned_key(_METRICS_PREFIX, suffix)


def _build_usage_metrics_result(
    *,
    total_completions: int,
    completions_last_7_days: int,
    unique_users_completed: int,
    before_training_count: int,
    after_training_count: int,
) -> dict:
    total_usage = before_training_count + after_training_count
    before_percent = round((before_training_count / total_usage * 100.0), 1) if total_usage > 0 else 0.0
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
    cache_key = await _metrics_cache_key("usage:global")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached
    total = await db.scalar(select(func.count(LessonProgress.id))) or 0

    since_7_days = datetime.now(UTC) - timedelta(days=7)
    last_7 = (
        await db.scalar(select(func.count(LessonProgress.id)).where(LessonProgress.completed_at >= since_7_days)) or 0
    )

    unique_users = await db.scalar(select(func.count(func.distinct(LessonProgress.user_id)))) or 0

    before = (
        await db.scalar(select(func.count(MissionUsage.id)).where(MissionUsage.usage_type == "before_training")) or 0
    )
    after = await db.scalar(select(func.count(MissionUsage.id)).where(MissionUsage.usage_type == "after_training")) or 0

    result = _build_usage_metrics_result(
        total_completions=total,
        completions_last_7_days=last_7,
        unique_users_completed=unique_users,
        before_training_count=before,
        after_training_count=after,
    )
    logger.info("get_usage_metrics", extra=result)
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
    return result


async def get_usage_metrics_for_academy(db: AsyncSession, academy_id: uuid.UUID) -> dict:
    """
    Retorna métricas de uso filtradas por academy_id (para gestor local/global).
    """
    cache_key = await _metrics_cache_key(f"usage:academy:{academy_id}")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached
    # Filtro por academia via relação com User
    since_7_days = datetime.now(UTC) - timedelta(days=7)

    total = (
        await db.scalar(
            select(func.count(LessonProgress.id))
            .join(User, LessonProgress.user_id == User.id)
            .where(User.academy_id == academy_id)
        )
        or 0
    )

    last_7 = (
        await db.scalar(
            select(func.count(LessonProgress.id))
            .join(User, LessonProgress.user_id == User.id)
            .where(
                User.academy_id == academy_id,
                LessonProgress.completed_at >= since_7_days,
            )
        )
        or 0
    )

    unique_users = (
        await db.scalar(
            select(func.count(func.distinct(LessonProgress.user_id)))
            .join(User, LessonProgress.user_id == User.id)
            .where(User.academy_id == academy_id)
        )
        or 0
    )

    before = (
        await db.scalar(
            select(func.count(MissionUsage.id))
            .join(User, MissionUsage.user_id == User.id)
            .where(
                User.academy_id == academy_id,
                MissionUsage.usage_type == "before_training",
            )
        )
        or 0
    )

    after = (
        await db.scalar(
            select(func.count(MissionUsage.id))
            .join(User, MissionUsage.user_id == User.id)
            .where(
                User.academy_id == academy_id,
                MissionUsage.usage_type == "after_training",
            )
        )
        or 0
    )

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
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
    return result


async def _compute_engagement_for_period(
    db: AsyncSession,
    *,
    start: date,
    end: date,
    academy_id: uuid.UUID | None,
) -> dict:
    """Calcula % de alunos ativos em um período (start..end)."""
    # Limites do calendário no fuso do app, comparados a last_login_at (UTC no banco).
    start_dt = combine_local_date_start_utc(start)
    end_dt = combine_local_date_end_utc(end)

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

    active_rate = round(active_students / total_students * 100.0, 1) if total_students > 0 else 0.0

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
    cache_key = await _metrics_cache_key(f"engagement:{reference_date}:{academy_id}")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

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
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
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
    cache_key = await _metrics_cache_key(f"active_students:{reference_date}:{academy_id}")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

    window_end = reference_date
    window_start = reference_date - timedelta(days=6)

    # Resumo numérico (reaproveita a mesma lógica de engajamento)
    summary = await _compute_engagement_for_period(
        db,
        start=window_start,
        end=window_end,
        academy_id=academy_id,
    )

    start_dt = combine_local_date_start_utc(window_start)
    end_dt = combine_local_date_end_utc(window_end)

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
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
    return result


async def get_weekly_panel_logins_report(
    db: AsyncSession,
    *,
    reference_date: date | None,
    academy_id: uuid.UUID | None,
    range_start: date | None = None,
    range_end: date | None = None,
) -> dict:
    """
    Relatório de logins (user_login_days) num intervalo de datas.

    - Modo intervalo: `range_start` e `range_end` (inclusive); o limite máximo de
      dias é validado na rota HTTP.
    - Modo semana ISO: se o intervalo não for passado, usa a semana ISO que contém
      `reference_date` (default hoje se `reference_date` for None).

    Regras:
    - Roles elegíveis: administrador, gerente_academia, professor, supervisor e aluno.
    - Escopo por academia: apenas usuários com User.academy_id == academy_id.
      (admins globais sem academy_id aparecem somente na visão global).
    - Escopo global: todos os usuários elegíveis.
    """
    if range_start is not None and range_end is not None:
        week_start = range_start
        week_end = range_end
    else:
        ref = reference_date if reference_date is not None else today_in_app_tz()
        iso_year, iso_week, _ = ref.isocalendar()
        monday = datetime.fromisocalendar(iso_year, iso_week, 1).date()
        week_start = monday
        week_end = monday + timedelta(days=6)

    cache_key = await _metrics_cache_key(f"weekly_logins:{week_start}:{week_end}:{academy_id}:{reference_date}")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

    eligible_users_query = select(User).where(User.role.in_(_WEEKLY_LOGIN_REPORT_ROLES)).order_by(User.email)
    if academy_id is not None:
        eligible_users_query = eligible_users_query.where(User.academy_id == academy_id)
    eligible_users = (await db.execute(eligible_users_query)).scalars().all()
    if not eligible_users:
        empty = {
            "academy_id": str(academy_id) if academy_id is not None else None,
            "week_start": week_start,
            "week_end": week_end,
            "eligible_users_count": 0,
            "users_logged_at_least_once": 0,
            "users": [],
        }
        await app_cache.set(cache_key, empty, ttl=_METRICS_TTL_SEC)
        return empty

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
        "total_login_days": len(login_rows),
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
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
    return result


async def get_technique_execution_summary(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID | None,
) -> dict:
    """
    Resumo de execuções de técnicas (before_training = planejadas, after_training = naturais).
    Filtra apenas execuções confirmadas.
    """
    cache_key = await _metrics_cache_key(f"technique_exec_summary:{academy_id}")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

    base_where = [TechniqueExecution.status == "confirmed"]

    if academy_id is not None:
        base_where.append(TechniqueExecution.user_id.in_(select(User.id).where(User.academy_id == academy_id)))

    before = (
        await db.scalar(
            select(func.count(TechniqueExecution.id)).where(
                *base_where,
                TechniqueExecution.usage_type == "before_training",
            )
        )
        or 0
    )

    after = (
        await db.scalar(
            select(func.count(TechniqueExecution.id)).where(
                *base_where,
                TechniqueExecution.usage_type == "after_training",
            )
        )
        or 0
    )

    total = before + after
    before_percent = round(before / total * 100.0, 1) if total > 0 else 0.0

    result = {
        "academy_id": str(academy_id) if academy_id is not None else None,
        "before_training_count": before,
        "after_training_count": after,
        "total": total,
        "before_training_percent": before_percent,
    }
    logger.info("get_technique_execution_summary", extra=result)
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
    return result


async def get_students_attention_report(
    db: AsyncSession,
    *,
    academy_id: uuid.UUID | None,
    limit: int = 20,
) -> dict:
    """
    Alunos que há mais tempo não aparecem em nenhuma aula (última presença mais antiga).
    Inclui alunos que nunca tiveram presença (last_seen_at = null) — aparecem primeiro.
    """
    cache_key = await _metrics_cache_key(f"students_attention:{academy_id}:{limit}")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

    last_seen_subq = (
        select(
            AttendanceRecord.user_id.label("uid"),
            func.max(AttendanceRecord.checked_in_at).label("last_seen"),
        )
        .select_from(AttendanceRecord)
        .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
        .group_by(AttendanceRecord.user_id)
    ).subquery()

    from sqlalchemy import case as sa_case

    users_query = (
        select(
            User.id,
            User.email,
            User.name,
            User.graduation,
            User.academy_id,
            last_seen_subq.c.last_seen,
        )
        .select_from(User)
        .outerjoin(last_seen_subq, User.id == last_seen_subq.c.uid)
        .where(User.role == "aluno")
        .order_by(
            # Quem já frequentou mas parou vem primeiro (last_seen mais antiga primeiro)
            # Quem nunca compareceu vem por último
            sa_case((last_seen_subq.c.last_seen.is_(None), 1), else_=0).asc(),
            last_seen_subq.c.last_seen.asc(),
        )
        .limit(limit)
    )
    if academy_id is not None:
        users_query = users_query.where(User.academy_id == academy_id)

    total_query = select(func.count(User.id)).where(User.role == "aluno")
    if academy_id is not None:
        total_query = total_query.where(User.academy_id == academy_id)

    rows = (await db.execute(users_query)).all()
    total_students = await db.scalar(total_query) or 0

    now = datetime.now(UTC)
    students = []
    for uid, email, name, grad, acad_id, last_seen in rows:
        days_absent: int | None = None
        if last_seen is not None:
            ls = last_seen if last_seen.tzinfo else last_seen.replace(tzinfo=UTC)
            days_absent = (now - ls).days
        students.append(
            {
                "user_id": str(uid),
                "email": email,
                "name": name,
                "graduation": grad,
                "academy_id": str(acad_id) if acad_id is not None else None,
                "academy_name": None,
                "last_seen_at": last_seen,
                "days_absent": days_absent,
            }
        )

    result = {
        "academy_id": str(academy_id) if academy_id is not None else None,
        "total_students": total_students,
        "students": students,
    }
    logger.info(
        "get_students_attention_report",
        extra={"academy_id": result["academy_id"], "count": len(students)},
    )
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
    return result


async def get_mission_completion_report(
    db: AsyncSession,
    *,
    from_date: date,
    to_date: date,
    academy_id: uuid.UUID | None,
) -> dict:
    """
    Taxa de conclusão de missões no período: % de alunos (role=aluno) que
    concluíram ao menos 1 missão (MissionUsage.completed_at dentro do range).
    """
    cache_key = await _metrics_cache_key(f"mission_completion:{from_date}:{to_date}:{academy_id}")
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

    start_dt = combine_local_date_start_utc(from_date)
    end_dt = combine_local_date_end_utc(to_date)

    total_query = select(func.count(User.id)).where(User.role == "aluno")
    if academy_id is not None:
        total_query = total_query.where(User.academy_id == academy_id)
    total_students = await db.scalar(total_query) or 0

    completed_subq = (
        select(MissionUsage.user_id)
        .join(User, MissionUsage.user_id == User.id)
        .where(
            User.role == "aluno",
            MissionUsage.completed_at.is_not(None),
            MissionUsage.completed_at >= start_dt,
            MissionUsage.completed_at <= end_dt,
        )
    )
    if academy_id is not None:
        completed_subq = completed_subq.where(User.academy_id == academy_id)
    completed_subq = completed_subq.distinct().subquery()

    users_completed = await db.scalar(select(func.count()).select_from(completed_subq)) or 0

    completion_rate = round(users_completed / total_students * 100.0, 1) if total_students > 0 else 0.0

    result = {
        "academy_id": str(academy_id) if academy_id is not None else None,
        "from_date": from_date,
        "to_date": to_date,
        "total_students": total_students,
        "users_completed": users_completed,
        "completion_rate": completion_rate,
    }
    logger.info(
        "get_mission_completion_report",
        extra={
            "academy_id": result["academy_id"],
            "from_date": str(from_date),
            "to_date": str(to_date),
            "users_completed": users_completed,
            "completion_rate": completion_rate,
        },
    )
    await app_cache.set(cache_key, result, ttl=_METRICS_TTL_SEC)
    return result


async def invalidate_metrics_cache() -> None:
    """
    Remove todas as entradas de cache de métricas/agregações do painel (prefixo ``metrics_report:``).

    Usado após alterações que afetam relatórios; também é chamado a partir de
    ``invalidate_academy_analytics_cache`` quando dados da academia mudam.
    """
    new_version = await app_cache.bump_prefix_version(_METRICS_PREFIX)
    logger.debug("invalidate_metrics_cache", extra={"cache_version": new_version})
