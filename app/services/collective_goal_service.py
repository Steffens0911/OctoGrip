"""Serviço de metas coletivas: criar, listar, obter atual com contagem."""
from datetime import date, datetime, time, timedelta
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.models import CollectiveGoal, Mission, TechniqueExecution, User


def create_goal(
    db: Session,
    academy_id: UUID | None,
    technique_id: UUID,
    target_count: int,
    start_date: date,
    end_date: date,
) -> CollectiveGoal:
    goal = CollectiveGoal(
        academy_id=academy_id,
        technique_id=technique_id,
        target_count=target_count,
        start_date=start_date,
        end_date=end_date,
    )
    db.add(goal)
    db.commit()
    db.refresh(goal)
    return goal


def list_goals_for_academy(
    db: Session,
    academy_id: UUID,
    start_date: date | None = None,
    end_date: date | None = None,
):
    q = (
        db.query(CollectiveGoal)
        .options(joinedload(CollectiveGoal.technique))
        .filter(CollectiveGoal.academy_id == academy_id)
    )
    if start_date is not None:
        q = q.filter(CollectiveGoal.end_date >= start_date)
    if end_date is not None:
        q = q.filter(CollectiveGoal.start_date <= end_date)
    return q.order_by(CollectiveGoal.start_date.desc()).all()


def get_current_goal_for_academy(
    db: Session,
    academy_id: UUID,
    today: date | None = None,
) -> CollectiveGoal | None:
    day = today or date.today()
    return (
        db.query(CollectiveGoal)
        .options(joinedload(CollectiveGoal.technique))
        .filter(
            CollectiveGoal.academy_id == academy_id,
            CollectiveGoal.start_date <= day,
            CollectiveGoal.end_date >= day,
        )
        .order_by(CollectiveGoal.created_at.desc())
        .first()
    )


def count_executions_for_goal(
    db: Session,
    goal: CollectiveGoal,
) -> int:
    """
    Conta technique_executions confirmadas para a técnica da meta,
    no período da meta, de usuários da academia (se goal.academy_id) ou global.
    """
    start_dt = datetime.combine(goal.start_date, time.min)
    end_next = datetime.combine(goal.end_date, time.min) + timedelta(days=1)
    q = (
        db.query(func.count(TechniqueExecution.id))
        .join(Mission, TechniqueExecution.mission_id == Mission.id)
        .filter(
            TechniqueExecution.status == "confirmed",
            Mission.technique_id == goal.technique_id,
            TechniqueExecution.created_at >= start_dt,
            TechniqueExecution.created_at < end_next,
        )
    )
    if goal.academy_id is not None:
        q = q.join(User, TechniqueExecution.user_id == User.id).filter(
            User.academy_id == goal.academy_id,
        )
    result = q.scalar()
    return int(result) if result is not None else 0
