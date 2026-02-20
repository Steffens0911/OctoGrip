"""Serviços de Academia (A-03, A-04)."""
import logging
import re
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func, select, delete as sa_delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Academy, LessonProgress, Mission, MissionUsage, Position, TechniqueExecution, TrainingFeedback, User
from app.services.mission_crud_service import upsert_academy_week_missions

logger = logging.getLogger(__name__)


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
            db, academy_id, (t1, t2, t3),
            date(2020, 1, 6), date(2099, 12, 31),
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
            select(
                MissionUsage.user_id,
                func.sum(MissionUsage.points_awarded).label("total_points")
            )
            .where(
                MissionUsage.mission_id.in_(mission_ids),
                MissionUsage.user_id.isnot(None)
            )
            .group_by(MissionUsage.user_id)
        )
    ).all()
    
    # Agregar pontos de TechniqueExecution por usuário
    te_points_rows = (
        await db.execute(
            select(
                TechniqueExecution.user_id,
                func.sum(TechniqueExecution.points_awarded).label("total_points")
            )
            .where(
                TechniqueExecution.mission_id.in_(mission_ids),
                TechniqueExecution.status == "confirmed"
            )
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


async def list_academies(db: AsyncSession, limit: int = 100) -> list[Academy]:
    """Lista academias (para painel do professor)."""
    return (await db.execute(select(Academy).order_by(Academy.name).limit(limit))).scalars().all()


async def create_academy(db: AsyncSession, name: str, slug: str | None = None) -> Academy:
    """Cria uma academia. Slug opcional (gerado a partir do nome se vazio)."""
    if not slug or not slug.strip():
        slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "academia"
    academy = Academy(name=name.strip(), slug=slug.strip())
    db.add(academy)
    await db.commit()
    await db.refresh(academy)
    logger.info("create_academy", extra={"academy_id": str(academy.id), "academy_name": academy.name})
    return academy


async def delete_academy(db: AsyncSession, academy_id: UUID) -> bool:
    """Remove uma academia. Retorna True se removeu, False se não existir."""
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return False
    await db.delete(academy)
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


async def update_academy(db: AsyncSession, academy_id: UUID, **kwargs) -> Academy | None:
    """Atualiza academia (campos em kwargs). Se alguma técnica for alterada, cria/atualiza missões da semana (até 3)."""
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return None
    technique_keys = {"weekly_technique_id", "weekly_technique_2_id", "weekly_technique_3_id"}
    multiplier_keys = {"weekly_multiplier_1", "weekly_multiplier_2", "weekly_multiplier_3"}
    for key, value in kwargs.items():
        if key == "name" and value is not None:
            academy.name = value.strip()
        elif key == "slug":
            academy.slug = value.strip() if value and value.strip() else None
        elif key == "weekly_theme":
            academy.weekly_theme = value
        elif key in technique_keys:
            setattr(academy, key, value)
        elif key == "visible_lesson_id":
            academy.visible_lesson_id = value
        elif key in multiplier_keys and value is not None and value >= 1:
            setattr(academy, key, value)
    if (technique_keys | multiplier_keys) & set(kwargs.keys()):
        t1 = academy.weekly_technique_id
        t2 = academy.weekly_technique_2_id
        t3 = academy.weekly_technique_3_id
        try:
            await upsert_academy_week_missions(
                db, academy_id, (t1, t2, t3),
                date(2020, 1, 6), date(2099, 12, 31),
            )
        except Exception as e:
            logger.exception("update_academy upsert_academy_week_missions: %s", e)
            raise
    await db.commit()
    await db.refresh(academy)
    logger.info("update_academy", extra={"academy_id": str(academy_id)})
    return academy


async def _get_user_completions_by_period(
    db: AsyncSession,
    academy_id: UUID,
    start: datetime,
    end: datetime | None = None,
) -> tuple[dict[UUID, tuple[str | None, int]], dict[UUID, tuple[str | None, int]]]:
    """
    Retorna (lp_by_user, mu_by_user) onde cada dict mapeia user_id para (name, count).
    lp_by_user: LessonProgress counts
    mu_by_user: MissionUsage counts
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
    lp_by_user: dict[UUID, tuple[str | None, int]] = {
        r[0]: (r[1], r[2]) for r in lp_rows
    }
    
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
    mu_by_user: dict[UUID, tuple[str | None, int]] = {
        r[0]: (r[1], r[2]) for r in mu_rows
    }
    
    return lp_by_user, mu_by_user


def _merge_user_completions(
    lp_by_user: dict[UUID, tuple[str | None, int]],
    mu_by_user: dict[UUID, tuple[str | None, int]],
    limit: int | None = None,
) -> list[tuple[UUID, str, int]]:
    """
    Combina LessonProgress e MissionUsage em ranking.
    Retorna lista de (user_id, name, total_count) ordenada por count desc.
    """
    all_user_ids = set(lp_by_user) | set(mu_by_user)
    if not all_user_ids:
        return []
    
    merged = []
    for uid in all_user_ids:
        # Priorizar nome de lp_by_user, depois mu_by_user
        name = (lp_by_user.get(uid) or (None, 0))[0] or (mu_by_user.get(uid) or (None, 0))[0] or ""
        count_lp = (lp_by_user.get(uid) or (None, 0))[1]
        count_mu = (mu_by_user.get(uid) or (None, 0))[1]
        merged.append((uid, name, count_lp + count_mu))
    
    merged.sort(key=lambda x: x[2], reverse=True)
    if limit is not None:
        merged = merged[:limit]
    
    return merged


async def get_academy_ranking(
    db: AsyncSession,
    academy_id: UUID,
    period_days: int = 30,
    limit: int = 50,
) -> list[dict]:
    """
    A-04: Ranking interno da academia por conclusões (LessonProgress + MissionUsage).
    Inclui conclusões por lição (POST /lesson_complete) e por missão do dia (POST /mission_complete).
    Retorna lista de { rank, user_id, name, completions_count } ordenada por count desc.
    Considera apenas conclusões nos últimos period_days dias.
    """
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return []

    since = datetime.now(timezone.utc) - timedelta(days=period_days)

    # Usar função comum para buscar completions
    lp_by_user, mu_by_user = await _get_user_completions_by_period(db, academy_id, since)
    
    # Merge e formatação
    merged = _merge_user_completions(lp_by_user, mu_by_user, limit=limit)
    logger.debug(
        "get_academy_ranking merge",
        extra={
            "academy_id": str(academy_id),
            "lp_users": len(lp_by_user),
            "mu_users": len(mu_by_user),
            "total_users": len(merged),
        },
    )
    
    return [
        {"rank": i + 1, "user_id": r[0], "name": r[1], "completions_count": r[2]}
        for i, r in enumerate(merged)
    ]


async def get_academy_weekly_report(
    db: AsyncSession,
    academy_id: UUID,
    year: int | None = None,
    week: int | None = None,
) -> dict | None:
    """
    T-03: Relatório semanal da academia (export simples).
    Inclui conclusões por lição (LessonProgress) e por missão do dia (MissionUsage).
    Se year/week não informados, usa a semana atual (ISO).
    Retorna week_start, week_end (ISO date), completions_count, active_users_count, entries (ranking da semana).
    """
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return None

    if year is not None and week is not None:
        d = datetime.fromisocalendar(year, week, 1).date()
    else:
        today = date.today()
        d = today - timedelta(days=today.weekday())
    week_start = datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
    week_end = week_start + timedelta(days=7)

    # Usar função comum para buscar completions
    lp_by_user, mu_by_user = await _get_user_completions_by_period(db, academy_id, week_start, week_end)
    
    # Merge usando função comum
    merged = _merge_user_completions(lp_by_user, mu_by_user)
    
    logger.debug(
        "get_academy_weekly_report merge",
        extra={
            "academy_id": str(academy_id),
            "lp_users": len(lp_by_user),
            "mu_users": len(mu_by_user),
            "total_users": len(merged),
        },
    )
    
    if not merged:
        return {
            "academy_id": academy_id,
            "week_start": d.isoformat(),
            "week_end": (d + timedelta(days=6)).isoformat(),
            "completions_count": 0,
            "active_users_count": 0,
            "entries": [],
        }
    
    total_completions = sum(r[2] for r in merged)
    return {
        "academy_id": academy_id,
        "week_start": d.isoformat(),
        "week_end": (d + timedelta(days=6)).isoformat(),
        "completions_count": total_completions,
        "active_users_count": len(merged),
        "entries": [
            {"rank": i + 1, "user_id": r[0], "name": r[1], "completions_count": r[2]}
            for i, r in enumerate(merged)
        ],
    }


async def get_academy_difficulties(
    db: AsyncSession,
    academy_id: UUID,
    limit: int = 50,
) -> list[dict]:
    """
    T-02: Posições mais marcadas como difíceis (TrainingFeedback).
    Filtra por usuários da academia; ordena por count desc.
    """
    academy = (await db.execute(select(Academy).where(Academy.id == academy_id))).scalar_one_or_none()
    if not academy:
        return []

    rows = (
        await db.execute(
            select(
                Position.id,
                Position.name,
                func.count(TrainingFeedback.id).label("count"),
            )
            .join(TrainingFeedback, TrainingFeedback.position_id == Position.id)
            .join(User, User.id == TrainingFeedback.user_id)
            .where(User.academy_id == academy_id)
            .group_by(Position.id, Position.name)
            .order_by(func.count(TrainingFeedback.id).desc())
            .limit(limit)
        )
    ).all()
    return [{"position_id": r[0], "position_name": r[1], "count": r[2]} for r in rows]
