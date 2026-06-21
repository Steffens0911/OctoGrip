"""Serviços de Academia (A-03, A-04)."""

import logging
import re
from datetime import UTC, date, datetime, timedelta
from uuid import UUID

from sqlalchemy import delete as sa_delete
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_time import (
    combine_local_date_exclusive_end_utc,
    combine_local_date_start_utc,
    today_in_app_tz,
)
from app.core.cache import app_cache
from app.core.exceptions import AppError
from app.core.points_limits import clamp_reward_points
from app.models import (
    Academy,
    LessonProgress,
    Mission,
    MissionUsage,
    Partner,
    TechniqueExecution,
    TrainingFeedback,
    User,
    UserWeeklyKitChoice,
)
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)
from app.services.metrics_service import invalidate_metrics_cache
from app.services.mission_crud_service import upsert_academy_week_missions
from app.services.weekly_kit_service import academy_has_active_weekly_kits
from app.utils.iso_week import iso_week_key_for_date, utc_datetime_bounds_for_iso_week

logger = logging.getLogger(__name__)

_ENTITY_ACADEMY = "Academy"

# Cache read-heavy (ranking / relatório semanal). Invalidar com `invalidate_academy_analytics_cache`.
ACADEMY_ANALYTICS_PREFIX = "academy_analytics:"
_ACADEMY_RANKING_TTL_SEC = 300
_ACADEMY_WEEKLY_REPORT_TTL_SEC = 900


async def invalidate_academy_analytics_cache(academy_id: UUID | None) -> None:
    """Remove entradas de cache de ranking e relatório semanal para uma academia."""
    if academy_id is None:
        return
    prefix = f"{ACADEMY_ANALYTICS_PREFIX}{academy_id}:"
    new_version = await app_cache.bump_prefix_version(prefix)
    logger.debug(
        "invalidate_academy_analytics_cache",
        extra={"academy_id": str(academy_id), "cache_version": new_version},
    )
    # Métricas globais/por academia (painel) dependem das mesmas fontes de dados.
    await invalidate_metrics_cache()


async def ensure_weekly_missions_if_needed(
    db: AsyncSession,
    academy_id: UUID,
    *,
    academy: Academy | None = None,
) -> None:
    """
    Se a academia tem técnicas configuradas, executa upsert para garantir que as missões
    existam (persistem enquanto configuradas).
    Se academy for passado, evita nova query.
    """
    if academy is None:
        academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return
    if await academy_has_active_weekly_kits(db, academy_id):
        return
    if (
        academy.weekly_technique_id is None
        and academy.weekly_technique_2_id is None
        and academy.weekly_technique_3_id is None
    ):
        return
    t1 = academy.weekly_technique_id
    t2 = academy.weekly_technique_2_id
    t3 = academy.weekly_technique_3_id
    try:
        await upsert_academy_week_missions(
            db,
            academy_id,
            (t1, t2, t3),
            date(2020, 1, 6),
            date(2099, 12, 31),
        )
        logger.info(
            "ensure_weekly_missions_if_needed",
            extra={"academy_id": str(academy_id)},
        )
    except Exception as e:
        logger.exception("ensure_weekly_missions_if_needed: %s", e)


async def get_academy(db: AsyncSession, academy_id: UUID) -> Academy | None:
    """Retorna a academia por ID."""
    return (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()


async def reset_academy_missions(db: AsyncSession, academy_id: UUID) -> dict:
    """
    Reinicia as missões da academia: limpa MissionUsage e TechniqueExecution
    das missões desta academia. Antes de excluir, soma os pontos de cada usuário
    e adiciona em points_adjustment para preservar a pontuação.
    Retorna {message, users_affected}.
    """
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return {"message": "Academia não encontrada.", "users_affected": 0}

    missions = (await db.execute(select(Mission).where(Mission.academy_id == academy_id))).scalars().all()
    mission_ids = [m.id for m in missions]
    if not mission_ids:
        await db.commit()
        return {"message": "Missões reiniciadas. Nenhuma conclusão existente.", "users_affected": 0}

    # Otimização: usar agregação SQL em vez de carregar todos os registros na memória
    # Agregar pontos de MissionUsage por usuário
    mu_points_rows = (
        await db.execute(
            select(MissionUsage.user_id, func.sum(MissionUsage.points_awarded).label("total_points"))
            .where(MissionUsage.mission_id.in_(mission_ids), MissionUsage.user_id.isnot(None))
            .group_by(MissionUsage.user_id)
        )
    ).all()

    # Agregar pontos de TechniqueExecution por usuário
    te_points_rows = (
        await db.execute(
            select(TechniqueExecution.user_id, func.sum(TechniqueExecution.points_awarded).label("total_points"))
            .where(TechniqueExecution.mission_id.in_(mission_ids), TechniqueExecution.status == "confirmed")
            .group_by(TechniqueExecution.user_id)
        )
    ).all()

    # Combinar pontos de ambas as fontes
    user_points: dict[UUID, int] = {}
    for row in mu_points_rows:
        if row.user_id and row.total_points:
            user_points[row.user_id] = user_points.get(row.user_id, 0) + int(row.total_points)
    for row in te_points_rows:
        if row.user_id and row.total_points:
            user_points[row.user_id] = user_points.get(row.user_id, 0) + int(row.total_points)

    # Otimização: buscar todos os usuários de uma vez em vez de N+1 queries
    if user_points:
        user_ids = list(user_points.keys())
        users = (await db.execute(select(User).where(User.id.in_(user_ids)))).scalars().all()
        user_dict = {u.id: u for u in users}
        for user_id, pts in user_points.items():
            if user_id in user_dict:
                user_dict[user_id].points_adjustment = (user_dict[user_id].points_adjustment or 0) + pts

    await db.execute(sa_delete(MissionUsage).where(MissionUsage.mission_id.in_(mission_ids)))
    await db.execute(sa_delete(TechniqueExecution).where(TechniqueExecution.mission_id.in_(mission_ids)))
    await db.commit()
    logger.info("reset_academy_missions", extra={"academy_id": str(academy_id), "users_affected": len(user_points)})
    return {"message": "Missões reiniciadas. Pontuação preservada.", "users_affected": len(user_points)}


async def reset_academy_weekly_turmas_week(db: AsyncSession, academy_id: UUID) -> dict:
    """
    Reinicia escolhas de turma (kit) e progresso na semana ISO atual (fusos APP_TIMEZONE):
    remove `user_weekly_kit_choices` dessa semana e `MissionUsage` / `TechniqueExecution`
    confirmadas ligadas a missões com `weekly_kit_id`, apenas com timestamps na janela
    da semana. Pontos dessas linhas somam em `points_adjustment` (como `reset_academy_missions`).
    """
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return {"message": "Academia não encontrada.", "users_affected": 0, "choices_removed": 0}

    if not await academy_has_active_weekly_kits(db, academy_id):
        raise AppError(
            "A academia não tem turmas ativas (1–5 técnicas). Crie uma turma antes de usar este reinício.",
            status_code=400,
        )

    iso_y, iso_w = iso_week_key_for_date()
    t_start, t_end = utc_datetime_bounds_for_iso_week(iso_y, iso_w)

    r_choices = await db.execute(
        sa_delete(UserWeeklyKitChoice).where(
            UserWeeklyKitChoice.academy_id == academy_id,
            UserWeeklyKitChoice.iso_week_year == iso_y,
            UserWeeklyKitChoice.iso_week_number == iso_w,
        )
    )
    choices_removed = r_choices.rowcount if r_choices.rowcount is not None else 0

    mission_ids_subq = select(Mission.id).where(
        Mission.academy_id == academy_id,
        Mission.weekly_kit_id.is_not(None),
        Mission.deleted_at.is_(None),
    )
    mission_ids = (await db.execute(mission_ids_subq)).scalars().all()
    if not mission_ids:
        await db.commit()
        return {
            "message": "Semana reiniciada (sem missões de turma). Escolhas de turma da semana removidas.",
            "users_affected": 0,
            "choices_removed": choices_removed,
            "iso_week_year": iso_y,
            "iso_week_number": iso_w,
        }

    mu_points_rows = (
        await db.execute(
            select(
                MissionUsage.user_id,
                func.coalesce(func.sum(MissionUsage.points_awarded), 0).label("total_points"),
            )
            .where(
                MissionUsage.mission_id.in_(mission_ids),
                MissionUsage.user_id.is_not(None),
                MissionUsage.completed_at >= t_start,
                MissionUsage.completed_at < t_end,
            )
            .group_by(MissionUsage.user_id)
        )
    ).all()

    te_points_rows = (
        await db.execute(
            select(
                TechniqueExecution.user_id,
                func.coalesce(func.sum(TechniqueExecution.points_awarded), 0).label("total_points"),
            )
            .where(
                TechniqueExecution.mission_id.in_(mission_ids),
                TechniqueExecution.status == "confirmed",
                TechniqueExecution.confirmed_at.is_not(None),
                TechniqueExecution.confirmed_at >= t_start,
                TechniqueExecution.confirmed_at < t_end,
            )
            .group_by(TechniqueExecution.user_id)
        )
    ).all()

    user_points: dict[UUID, int] = {}
    for row in mu_points_rows:
        if row.user_id and row.total_points:
            user_points[row.user_id] = user_points.get(row.user_id, 0) + int(row.total_points)
    for row in te_points_rows:
        if row.user_id and row.total_points:
            user_points[row.user_id] = user_points.get(row.user_id, 0) + int(row.total_points)

    if user_points:
        user_ids = list(user_points.keys())
        users = (await db.execute(select(User).where(User.id.in_(user_ids)))).scalars().all()
        user_dict = {u.id: u for u in users}
        for uid, pts in user_points.items():
            if uid in user_dict:
                user_dict[uid].points_adjustment = (user_dict[uid].points_adjustment or 0) + pts

    await db.execute(
        sa_delete(MissionUsage).where(
            MissionUsage.mission_id.in_(mission_ids),
            MissionUsage.completed_at >= t_start,
            MissionUsage.completed_at < t_end,
        )
    )
    await db.execute(
        sa_delete(TechniqueExecution).where(
            TechniqueExecution.mission_id.in_(mission_ids),
            TechniqueExecution.status == "confirmed",
            TechniqueExecution.confirmed_at.is_not(None),
            TechniqueExecution.confirmed_at >= t_start,
            TechniqueExecution.confirmed_at < t_end,
        )
    )
    await db.commit()
    logger.info(
        "reset_academy_weekly_turmas_week",
        extra={
            "academy_id": str(academy_id),
            "iso_week": f"{iso_y}-W{iso_w}",
            "users_affected": len(user_points),
            "choices_removed": choices_removed,
        },
    )
    return {
        "message": "Semana das turmas reiniciada (horário de Brasília). Pontuação preservada.",
        "users_affected": len(user_points),
        "choices_removed": choices_removed,
        "iso_week_year": iso_y,
        "iso_week_number": iso_w,
    }


async def list_academies(db: AsyncSession, limit: int = 100) -> list[Academy]:
    """Lista academias (para painel do professor)."""
    return (await db.execute(select(Academy).order_by(Academy.name).limit(limit))).scalars().all()


async def create_academy(
    db: AsyncSession,
    name: str,
    slug: str | None = None,
    *,
    audit_user_id: UUID | None = None,
) -> Academy:
    """Cria uma academia. Slug opcional (gerado a partir do nome se vazio)."""
    if not slug or not slug.strip():
        slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "academia"
    academy = Academy(name=name.strip(), slug=slug.strip())
    db.add(academy)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_ENTITY_ACADEMY,
        entity_id=academy.id,
        old_data=None,
        new_data=entity_snapshot_row(academy),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(academy)
    logger.info("create_academy", extra={"academy_id": str(academy.id), "academy_name": academy.name})
    return academy


async def delete_academy(
    db: AsyncSession,
    academy_id: UUID,
    *,
    audit_user_id: UUID | None = None,
) -> bool:
    """Remove uma academia. Retorna True se removeu, False se não existir.

    Usa DELETE SQL em vez de session.delete(Academy): o ORM, por omissão, tentava
    UPDATE em técnicas (academy_id NOT NULL) antes do DELETE, gerando IntegrityError.
    A cascata na base remove filhos (técnicas, troféus, etc.) conforme as FKs.
    """
    academy = await get_academy(db, academy_id)
    if not academy:
        return False
    before = entity_snapshot_row(academy)
    # Parceiros: remoção explícita (legado / ordem de flush); a FK também permite CASCADE.
    await db.execute(sa_delete(Partner).where(Partner.academy_id == academy_id))
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_ENTITY_ACADEMY,
        entity_id=academy_id,
        old_data=before,
        new_data=None,
        user_id=audit_user_id,
    )
    await db.execute(sa_delete(Academy).where(Academy.id == academy_id))
    await db.commit()
    logger.info("delete_academy", extra={"academy_id": str(academy_id)})
    return True


async def update_academy_weekly_theme(
    db: AsyncSession,
    academy_id: UUID,
    weekly_theme: str | None,
) -> Academy | None:
    """A-03: Atualiza o tema semanal da academia (professor define)."""
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return None
    academy.weekly_theme = weekly_theme
    await db.commit()
    await db.refresh(academy)
    logger.info(
        "update_academy_weekly_theme",
        extra={"academy_id": str(academy_id), "weekly_theme": weekly_theme},
    )
    return academy


async def update_academy(
    db: AsyncSession,
    academy_id: UUID,
    *,
    audit_user_id: UUID | None = None,
    **kwargs,
) -> Academy | None:
    """Atualiza academia (campos em kwargs). Se alguma técnica for alterada, cria/atualiza missões da semana (até 3)."""
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return None
    before = entity_snapshot_row(academy)
    technique_keys = {"weekly_technique_id", "weekly_technique_2_id", "weekly_technique_3_id"}
    multiplier_keys = {"weekly_multiplier_1", "weekly_multiplier_2", "weekly_multiplier_3"}
    visibility_keys = {"show_trophies", "show_partners", "show_schedule", "show_global_supporters"}
    for key, value in kwargs.items():
        if key == "name" and value is not None:
            academy.name = value.strip()
        elif key == "slug":
            academy.slug = value.strip() if value and value.strip() else None
        elif key == "logo_url":
            academy.logo_url = value.strip() if value and value.strip() else None
        elif key == "schedule_image_url":
            academy.schedule_image_url = value.strip() if value and value.strip() else None
        elif key == "weekly_theme":
            academy.weekly_theme = value
        elif key in technique_keys:
            setattr(academy, key, value)
        elif key == "visible_lesson_id":
            academy.visible_lesson_id = value
        elif key in multiplier_keys and value is not None:
            setattr(academy, key, clamp_reward_points(int(value)))
        elif key in visibility_keys and value is not None:
            setattr(academy, key, bool(value))
        elif key == "face_recognition_enabled" and value is not None:
            academy.face_recognition_enabled = bool(value)
        elif key == "qr_attendance_enabled" and value is not None:
            academy.qr_attendance_enabled = bool(value)
        elif key == "octophotos_enabled" and value is not None:
            academy.octophotos_enabled = bool(value)
        elif key == "pre_checkin_enabled" and value is not None:
            academy.pre_checkin_enabled = bool(value)
        elif key == "pre_checkin_strict" and value is not None:
            academy.pre_checkin_strict = bool(value)
        elif key == "face_checkin_enabled" and value is not None:
            academy.face_checkin_enabled = bool(value)
        elif key == "punctuality_xp" and value is not None:
            academy.punctuality_xp = max(0, min(100, int(value)))
        elif key == "login_notice_title":
            academy.login_notice_title = value.strip() if value and str(value).strip() else None
        elif key == "login_notice_body":
            academy.login_notice_body = value.strip() if value and str(value).strip() else None
        elif key == "login_notice_url":
            academy.login_notice_url = value.strip() if value and str(value).strip() else None
        elif key == "login_notice_active" and value is not None:
            academy.login_notice_active = bool(value)
    if (technique_keys | multiplier_keys) & set(kwargs.keys()):
        if not await academy_has_active_weekly_kits(db, academy_id):
            t1 = academy.weekly_technique_id
            t2 = academy.weekly_technique_2_id
            t3 = academy.weekly_technique_3_id
            try:
                await upsert_academy_week_missions(
                    db,
                    academy_id,
                    (t1, t2, t3),
                    date(2020, 1, 6),
                    date(2099, 12, 31),
                )
            except Exception as e:
                logger.exception("update_academy upsert_academy_week_missions: %s", e)
                raise
    # Não fazer refresh aqui: os campos já foram aplicados em memória e ainda
    # não foram persistidos — refresh recarregaria valores antigos da BD.
    after = entity_snapshot_row(academy)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_ENTITY_ACADEMY,
            entity_id=academy_id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(academy)
    logger.info("update_academy", extra={"academy_id": str(academy_id)})
    return academy


async def _get_user_completions_by_period(
    db: AsyncSession,
    academy_id: UUID,
    start: datetime,
    end: datetime | None = None,
) -> tuple[
    dict[UUID, tuple[str | None, int]],
    dict[UUID, tuple[str | None, int]],
    dict[UUID, tuple[str | None, int]],
]:
    """
    Retorna (lp_by_user, mu_by_user, te_by_user) onde cada dict mapeia user_id para (name, count).
    lp_by_user: LessonProgress counts
    mu_by_user: MissionUsage counts
    te_by_user: TechniqueExecution confirmadas counts
    """
    # Query LessonProgress
    lp_query = (
        select(
            User.id,
            User.name,
            func.count(LessonProgress.id).label("count"),
        )
        .join(LessonProgress, LessonProgress.user_id == User.id)
        .where(
            User.academy_id == academy_id,
            LessonProgress.completed_at >= start,
        )
    )
    if end is not None:
        lp_query = lp_query.where(LessonProgress.completed_at < end)

    lp_rows = (await db.execute(lp_query.group_by(User.id, User.name))).all()
    lp_by_user: dict[UUID, tuple[str | None, int]] = {r[0]: (r[1], r[2]) for r in lp_rows}

    # Query MissionUsage
    mu_query = (
        select(
            User.id,
            User.name,
            func.count(MissionUsage.id).label("count"),
        )
        .join(MissionUsage, MissionUsage.user_id == User.id)
        .where(
            User.academy_id == academy_id,
            MissionUsage.completed_at >= start,
        )
    )
    if end is not None:
        mu_query = mu_query.where(MissionUsage.completed_at < end)

    mu_rows = (await db.execute(mu_query.group_by(User.id, User.name))).all()
    mu_by_user: dict[UUID, tuple[str | None, int]] = {r[0]: (r[1], r[2]) for r in mu_rows}

    # Query TechniqueExecution (somente confirmadas no período)
    te_event_time = func.coalesce(TechniqueExecution.confirmed_at, TechniqueExecution.created_at)
    te_query = (
        select(
            User.id,
            User.name,
            func.count(TechniqueExecution.id).label("count"),
        )
        .join(TechniqueExecution, TechniqueExecution.user_id == User.id)
        .where(
            User.academy_id == academy_id,
            TechniqueExecution.status == "confirmed",
            te_event_time >= start,
        )
    )
    if end is not None:
        te_query = te_query.where(te_event_time < end)

    te_rows = (await db.execute(te_query.group_by(User.id, User.name))).all()
    te_by_user: dict[UUID, tuple[str | None, int]] = {r[0]: (r[1], r[2]) for r in te_rows}

    return lp_by_user, mu_by_user, te_by_user


def _merge_user_completions(
    lp_by_user: dict[UUID, tuple[str | None, int]],
    mu_by_user: dict[UUID, tuple[str | None, int]],
    te_by_user: dict[UUID, tuple[str | None, int]],
    limit: int | None = None,
) -> list[tuple[UUID, str, int]]:
    """
    Combina LessonProgress e MissionUsage em ranking.
    Retorna lista de (user_id, name, total_count) ordenada por count desc.
    """
    all_user_ids = set(lp_by_user) | set(mu_by_user) | set(te_by_user)
    if not all_user_ids:
        return []

    merged = []
    for uid in all_user_ids:
        # Priorizar nome de lp_by_user, depois mu_by_user, depois te_by_user
        name = (
            (lp_by_user.get(uid) or (None, 0))[0]
            or (mu_by_user.get(uid) or (None, 0))[0]
            or (te_by_user.get(uid) or (None, 0))[0]
            or ""
        )
        count_lp = (lp_by_user.get(uid) or (None, 0))[1]
        count_mu = (mu_by_user.get(uid) or (None, 0))[1]
        count_te = (te_by_user.get(uid) or (None, 0))[1]
        merged.append((uid, name, count_lp + count_mu + count_te))

    merged.sort(key=lambda x: x[2], reverse=True)
    if limit is not None:
        merged = merged[:limit]

    return merged


async def get_academy_ranking(
    db: AsyncSession,
    academy_id: UUID,
    period_days: int = 30,
    limit: int = 50,
    *,
    range_start: date | None = None,
    range_end: date | None = None,
) -> list[dict]:
    """
    A-04: Ranking interno da academia por conclusões (LessonProgress + MissionUsage).
    Inclui conclusões por lição (POST /lesson_complete), por missão do dia
    (POST /mission_complete) e execuções confirmadas (TechniqueExecution).
    Retorna lista de { rank, user_id, name, completions_count } ordenada por count desc.

    - Com `range_start` e `range_end` (datas inclusive no fuso APP_TIMEZONE): filtra o intervalo
      [início do dia local range_start, fim exclusivo do dia seguinte a range_end).
    - Caso contrário: últimos `period_days` dias a partir do instante atual (UTC).
    """
    cache_prefix = f"{ACADEMY_ANALYTICS_PREFIX}{academy_id}:"
    cache_key = await app_cache.versioned_key(
        cache_prefix,
        (
            "ranking:"
            f"{period_days}:{limit}:"
            f"{range_start.isoformat() if range_start else '_'}:"
            f"{range_end.isoformat() if range_end else '_'}"
        ),
    )
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return []

    if range_start is not None and range_end is not None:
        start_dt = combine_local_date_start_utc(range_start)
        end_dt = combine_local_date_exclusive_end_utc(range_end)
        lp_by_user, mu_by_user, te_by_user = await _get_user_completions_by_period(db, academy_id, start_dt, end_dt)
    else:
        since = datetime.now(UTC) - timedelta(days=period_days)
        lp_by_user, mu_by_user, te_by_user = await _get_user_completions_by_period(db, academy_id, since)

    # Merge e formatação
    merged = _merge_user_completions(lp_by_user, mu_by_user, te_by_user, limit=limit)
    logger.debug(
        "get_academy_ranking merge",
        extra={
            "academy_id": str(academy_id),
            "lp_users": len(lp_by_user),
            "mu_users": len(mu_by_user),
            "te_users": len(te_by_user),
            "total_users": len(merged),
        },
    )

    result = [{"rank": i + 1, "user_id": r[0], "name": r[1], "completions_count": r[2]} for i, r in enumerate(merged)]
    await app_cache.set(cache_key, result, ttl=_ACADEMY_RANKING_TTL_SEC)
    return result


async def get_academy_weekly_report(
    db: AsyncSession,
    academy_id: UUID,
    year: int | None = None,
    week: int | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
) -> dict | None:
    """
    T-03: Relatório de conclusões da academia (export simples).
    Inclui conclusões por lição (LessonProgress), por missão do dia (MissionUsage)
    e execuções confirmadas (TechniqueExecution).

    - Com `start_date` e `end_date` (inclusive): intervalo em calendário no fuso APP_TIMEZONE
      (ignora year/week).
    - Senão, se year/week informados: semana ISO correspondente.
    - Senão: semana ISO atual.
    Retorna week_start, week_end (datas do período), completions_count, active_users_count, entries.
    """
    cache_prefix = f"{ACADEMY_ANALYTICS_PREFIX}{academy_id}:"
    cache_key = await app_cache.versioned_key(
        cache_prefix,
        f"weekly:{start_date}:{end_date}:{year}:{week}",
    )
    cached = await app_cache.get(cache_key)
    if cached is not None:
        return cached

    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return None

    if start_date is not None and end_date is not None:
        label_start = start_date
        label_end = end_date
        week_start = combine_local_date_start_utc(start_date)
        week_end = combine_local_date_exclusive_end_utc(end_date)
    elif year is not None and week is not None:
        monday_d = datetime.fromisocalendar(year, week, 1).date()
        label_start = monday_d
        label_end = monday_d + timedelta(days=6)
        week_start = combine_local_date_start_utc(monday_d)
        week_end = combine_local_date_exclusive_end_utc(monday_d + timedelta(days=6))
    else:
        today = today_in_app_tz()
        monday_d = today - timedelta(days=today.weekday())
        label_start = monday_d
        label_end = monday_d + timedelta(days=6)
        week_start = combine_local_date_start_utc(monday_d)
        week_end = combine_local_date_exclusive_end_utc(monday_d + timedelta(days=6))

    # Usar função comum para buscar completions
    lp_by_user, mu_by_user, te_by_user = await _get_user_completions_by_period(db, academy_id, week_start, week_end)

    # Merge usando função comum
    merged = _merge_user_completions(lp_by_user, mu_by_user, te_by_user)

    logger.debug(
        "get_academy_weekly_report merge",
        extra={
            "academy_id": str(academy_id),
            "lp_users": len(lp_by_user),
            "mu_users": len(mu_by_user),
            "te_users": len(te_by_user),
            "total_users": len(merged),
        },
    )

    if not merged:
        empty = {
            "academy_id": academy_id,
            "week_start": label_start.isoformat(),
            "week_end": label_end.isoformat(),
            "completions_count": 0,
            "active_users_count": 0,
            "entries": [],
        }
        await app_cache.set(cache_key, empty, ttl=_ACADEMY_WEEKLY_REPORT_TTL_SEC)
        return empty

    total_completions = sum(r[2] for r in merged)
    out = {
        "academy_id": academy_id,
        "week_start": label_start.isoformat(),
        "week_end": label_end.isoformat(),
        "completions_count": total_completions,
        "active_users_count": len(merged),
        "entries": [
            {"rank": i + 1, "user_id": r[0], "name": r[1], "completions_count": r[2]} for i, r in enumerate(merged)
        ],
    }
    await app_cache.set(cache_key, out, ttl=_ACADEMY_WEEKLY_REPORT_TTL_SEC)
    return out


async def get_academy_difficulties(
    db: AsyncSession,
    academy_id: UUID,
    limit: int = 50,
) -> list[dict]:
    """
    T-02: Principais dificuldades reportadas (texto livre em TrainingFeedback).
    Filtra por usuários da academia; ordena por count desc.
    """
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return []

    # Contar ocorrências por nota (texto) não nula, normalizada (trim e lower)
    # Nota: usamos expressão SQL para normalizar evitando trazer tudo à memória.
    note_expr = func.trim(func.lower(TrainingFeedback.note))
    rows = (
        await db.execute(
            select(
                note_expr.label("note_norm"),
                func.count(TrainingFeedback.id).label("count"),
            )
            .join(User, User.id == TrainingFeedback.user_id)
            .where(
                User.academy_id == academy_id,
                TrainingFeedback.note.isnot(None),
                func.length(func.trim(TrainingFeedback.note)) > 0,
            )
            .group_by(note_expr)
            .order_by(func.count(TrainingFeedback.id).desc())
            .limit(limit)
        )
    ).all()
    return [{"observation": r[0], "count": r[1]} for r in rows]
