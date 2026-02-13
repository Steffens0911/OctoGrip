"""Serviços de Academia (A-03, A-04)."""
import logging
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import Academy, LessonProgress, Position, TrainingFeedback, User

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


def update_academy(
    db: Session,
    academy_id: UUID,
    *,
    name: str | None = None,
    slug: str | None = None,
    weekly_theme: str | None = None,
) -> Academy | None:
    """Atualiza academia (campos opcionais)."""
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return None
    if name is not None:
        academy.name = name.strip()
    if slug is not None:
        academy.slug = slug.strip() if slug.strip() else None
    if weekly_theme is not None:
        academy.weekly_theme = weekly_theme
    db.commit()
    db.refresh(academy)
    logger.info(
        "update_academy",
        extra={"academy_id": str(academy_id)},
    )
    return academy


def get_academy_ranking(
    db: Session,
    academy_id: UUID,
    period_days: int = 30,
    limit: int = 50,
) -> list[dict]:
    """
    A-04: Ranking interno da academia por missões concluídas (LessonProgress).
    Retorna lista de { rank, user_id, name, completions_count } ordenada por count desc.
    Considera apenas conclusões nos últimos period_days dias.
    """
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return []

    since = datetime.now(timezone.utc) - timedelta(days=period_days)
    rows = (
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
        .order_by(func.count(LessonProgress.id).desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "rank": i + 1,
            "user_id": r[0],
            "name": r[1],
            "completions_count": r[2],
        }
        for i, r in enumerate(rows)
    ]


def get_academy_weekly_report(
    db: Session,
    academy_id: UUID,
    year: int | None = None,
    week: int | None = None,
) -> dict | None:
    """
    T-03: Relatório semanal da academia (export simples).
    Se year/week não informados, usa a semana atual (ISO).
    Retorna week_start, week_end (ISO date), completions_count, active_users_count, entries (ranking da semana).
    """
    academy = db.query(Academy).filter(Academy.id == academy_id).first()
    if not academy:
        return None

    if year is not None and week is not None:
        # ISO week: first day of week (Monday)
        d = datetime.fromisocalendar(year, week, 1).date()
    else:
        today = date.today()
        d = today - timedelta(days=today.weekday())  # Monday
    week_start = datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
    week_end = week_start + timedelta(days=7)

    since_7 = datetime.now(timezone.utc) - timedelta(days=7)
    rows = (
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
        .order_by(func.count(LessonProgress.id).desc())
        .all()
    )
    total_completions = sum(r[2] for r in rows)
    return {
        "academy_id": academy_id,
        "week_start": d.isoformat(),
        "week_end": (d + timedelta(days=6)).isoformat(),
        "completions_count": total_completions,
        "active_users_count": len(rows),
        "entries": [
            {"rank": i + 1, "user_id": r[0], "name": r[1], "completions_count": r[2]}
            for i, r in enumerate(rows)
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
