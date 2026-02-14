"""Serviços de Academia (A-03, A-04)."""
import logging
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import Academy, LessonProgress, MissionUsage, Position, TrainingFeedback, User
from app.services.mission_crud_service import upsert_academy_week_missions

logger = logging.getLogger(__name__)


def get_academy(db: Session, academy_id: UUID) -> Academy | None:
    """Retorna a academia por ID."""
    return db.query(Academy).filter(Academy.id == academy_id).first()


def list_academies(db: Session, limit: int = 100) -> list[Academy]:
    """Lista academias (para painel do professor)."""
    return db.query(Academy).order_by(Academy.name).limit(limit).all()


def create_academy(db: Session, name: str, slug: str | None = None) -> Academy:
    """Cria uma academia. Slug opcional (gerado a partir do nome se vazio)."""
    import re
    if not slug or not slug.strip():
        slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "academia"
    academy = Academy(name=name.strip(), slug=slug.strip())
    db.add(academy)
    db.commit()
    db.refresh(academy)
    logger.info("create_academy", extra={"academy_id": str(academy.id), "academy_name": academy.name})
    return academy


def delete_academy(db: Session, academy_id: UUID) -> bool:
    """Remove uma academia. Retorna True se removeu, False se não existir."""
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return False
    db.delete(academy)
    db.commit()
    logger.info("delete_academy", extra={"academy_id": str(academy_id)})
    return True


def update_academy_weekly_theme(
    db: Session,
    academy_id: UUID,
    weekly_theme: str | None,
) -> Academy | None:
    """A-03: Atualiza o tema semanal da academia (professor define)."""
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return None
    academy.weekly_theme = weekly_theme
    db.commit()
    db.refresh(academy)
    logger.info(
        "update_academy_weekly_theme",
        extra={"academy_id": str(academy_id), "weekly_theme": weekly_theme},
    )
    return academy


def update_academy(db: Session, academy_id: UUID, **kwargs) -> Academy | None:
    """Atualiza academia (campos em kwargs). Se alguma técnica for alterada, cria/atualiza missões da semana (até 3)."""
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return None
    technique_keys = {"weekly_technique_id", "weekly_technique_2_id", "weekly_technique_3_id"}
    for key, value in kwargs.items():
        if key == "name" and value is not None:
            academy.name = value.strip()
        elif key == "slug":
            academy.slug = value.strip() if value and value.strip() else None
        elif key == "weekly_theme":
            academy.weekly_theme = value
        elif key in technique_keys:
            setattr(academy, key, value)
    # Se alguma técnica foi alterada, (re)criar missões da semana
    if technique_keys & set(kwargs.keys()):
        today = date.today()
        week_start = today - timedelta(days=today.weekday())
        week_end = week_start + timedelta(days=6)
        t1 = academy.weekly_technique_id
        t2 = academy.weekly_technique_2_id
        t3 = academy.weekly_technique_3_id
        try:
            upsert_academy_week_missions(db, academy_id, (t1, t2, t3), week_start, week_end)
        except Exception as e:
            logger.exception("update_academy upsert_academy_week_missions: %s", e)
            raise
    db.commit()
    db.refresh(academy)
    logger.info("update_academy", extra={"academy_id": str(academy_id)})
    return academy


def get_academy_ranking(
    db: Session,
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
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return []

    since = datetime.now(timezone.utc) - timedelta(days=period_days)

    # Contagem por LessonProgress (conclusão por lição)
    lp_rows = (
        db.query(
            User.id,
            User.name,
            func.count(LessonProgress.id).label("count"),
        )
        .join(LessonProgress, LessonProgress.user_id == User.id)
        .filter(
            User.academy_id == academy_id,
            LessonProgress.completed_at >= since,
        )
        .group_by(User.id, User.name)
        .all()
    )
    lp_by_user: dict[UUID, tuple[str | None, int]] = {
        r[0]: (r[1], r[2]) for r in lp_rows
    }

    # Contagem por MissionUsage (conclusão por missão do dia)
    mu_rows = (
        db.query(
            User.id,
            User.name,
            func.count(MissionUsage.id).label("count"),
        )
        .join(MissionUsage, MissionUsage.user_id == User.id)
        .filter(
            User.academy_id == academy_id,
            MissionUsage.completed_at >= since,
        )
        .group_by(User.id, User.name)
        .all()
    )
    mu_by_user: dict[UUID, int] = {r[0]: r[2] for r in mu_rows}

    # Unir user_ids e somar contagens; buscar nomes dos usuários
    all_user_ids = set(lp_by_user) | set(mu_by_user)
    if not all_user_ids:
        return []
    name_rows = db.query(User.id, User.name).filter(User.id.in_(all_user_ids)).all()
    names = {r[0]: r[1] for r in name_rows}
    merged = []
    for uid in all_user_ids:
        name = (lp_by_user.get(uid) or (None, 0))[0] or (mu_rows and next((r[1] for r in mu_rows if r[0] == uid), None)) or names.get(uid) or ""
        count_lp = (lp_by_user.get(uid) or (None, 0))[1]
        count_mu = mu_by_user.get(uid) or 0
        merged.append((uid, name, count_lp + count_mu))
    merged.sort(key=lambda x: x[2], reverse=True)
    return [
        {"rank": i + 1, "user_id": r[0], "name": r[1], "completions_count": r[2]}
        for i, r in enumerate(merged[:limit])
    ]


def get_academy_weekly_report(
    db: Session,
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
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return None

    if year is not None and week is not None:
        d = datetime.fromisocalendar(year, week, 1).date()
    else:
        today = date.today()
        d = today - timedelta(days=today.weekday())
    week_start = datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
    week_end = week_start + timedelta(days=7)

    # LessonProgress na semana
    lp_rows = (
        db.query(
            User.id,
            User.name,
            func.count(LessonProgress.id).label("count"),
        )
        .join(LessonProgress, LessonProgress.user_id == User.id)
        .filter(
            User.academy_id == academy_id,
            LessonProgress.completed_at >= week_start,
            LessonProgress.completed_at < week_end,
        )
        .group_by(User.id, User.name)
        .all()
    )
    lp_by_user = {r[0]: (r[1], r[2]) for r in lp_rows}

    # MissionUsage na semana
    mu_rows = (
        db.query(
            User.id,
            User.name,
            func.count(MissionUsage.id).label("count"),
        )
        .join(MissionUsage, MissionUsage.user_id == User.id)
        .filter(
            User.academy_id == academy_id,
            MissionUsage.completed_at >= week_start,
            MissionUsage.completed_at < week_end,
        )
        .group_by(User.id, User.name)
        .all()
    )
    mu_by_user = {r[0]: r[2] for r in mu_rows}

    all_user_ids = set(lp_by_user) | set(mu_by_user)
    if not all_user_ids:
        return {
            "academy_id": academy_id,
            "week_start": d.isoformat(),
            "week_end": (d + timedelta(days=6)).isoformat(),
            "completions_count": 0,
            "active_users_count": 0,
            "entries": [],
        }
    name_rows = db.query(User.id, User.name).filter(User.id.in_(all_user_ids)).all()
    names = {r[0]: r[1] for r in name_rows}
    merged = []
    for uid in all_user_ids:
        name = (lp_by_user.get(uid) or (None, 0))[0] or next((r[1] for r in mu_rows if r[0] == uid), None) or names.get(uid) or ""
        count_lp = (lp_by_user.get(uid) or (None, 0))[1]
        count_mu = mu_by_user.get(uid) or 0
        merged.append((uid, name, count_lp + count_mu))
    merged.sort(key=lambda x: x[2], reverse=True)
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


def get_academy_difficulties(
    db: Session,
    academy_id: UUID,
    limit: int = 50,
) -> list[dict]:
    """
    T-02: Posições mais marcadas como difíceis (TrainingFeedback).
    Filtra por usuários da academia; ordena por count desc.
    """
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return []

    rows = (
        db.query(
            Position.id,
            Position.name,
            func.count(TrainingFeedback.id).label("count"),
        )
        .join(TrainingFeedback, TrainingFeedback.position_id == Position.id)
        .join(User, User.id == TrainingFeedback.user_id)
        .filter(User.academy_id == academy_id)
        .group_by(Position.id, Position.name)
        .order_by(func.count(TrainingFeedback.id).desc())
        .limit(limit)
        .all()
    )
    return [{"position_id": r[0], "position_name": r[1], "count": r[2]} for r in rows]
