"""Serviço de metas coletivas: criar, listar, obter atual com contagem."""
from datetime import date, datetime, time, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import CollectiveGoal, Mission, TechniqueExecution, User


async def create_goal(
    db: AsyncSession,
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
    await db.commit()
    await db.refresh(goal)
    return goal


async def list_goals_for_academy(
    db: AsyncSession,
    academy_id: UUID,
    start_date: date | None = None,
    end_date: date | None = None,
):
    stmt = (
        select(CollectiveGoal)
        .options(selectinload(CollectiveGoal.technique))
        .where(CollectiveGoal.academy_id == academy_id)
    )
    if start_date is not None:
        stmt = stmt.where(CollectiveGoal.end_date >= start_date)
    if end_date is not None:
        stmt = stmt.where(CollectiveGoal.start_date <= end_date)
    return (await db.execute(stmt.order_by(CollectiveGoal.start_date.desc()))).unique().scalars().all()


async def get_current_goal_for_academy(
    db: AsyncSession,
    academy_id: UUID,
    today: date | None = None,
) -> CollectiveGoal | None:
    day = today or date.today()
    return (
        await db.execute(
            select(CollectiveGoal)
            .options(selectinload(CollectiveGoal.technique))
            .where(
                CollectiveGoal.academy_id == academy_id,
                CollectiveGoal.start_date <= day,
                CollectiveGoal.end_date >= day,
            )
            .order_by(CollectiveGoal.created_at.desc())
        )
    ).unique().scalars().first()


async def count_executions_for_goal(
    db: AsyncSession,
    goal: CollectiveGoal,
) -> int:
    """
    Conta technique_executions confirmadas para a técnica da meta,
    no período da meta, de usuários da academia (se goal.academy_id) ou global.
    """
    start_dt = datetime.combine(goal.start_date, time.min)
    end_next = datetime.combine(goal.end_date, time.min) + timedelta(days=1)
    stmt = (
        select(func.count(TechniqueExecution.id))
        .join(Mission, TechniqueExecution.mission_id == Mission.id)
        .where(
            TechniqueExecution.status == "confirmed",
            Mission.technique_id == goal.technique_id,
            Mission.deleted_at.is_(None),
            TechniqueExecution.created_at >= start_dt,
            TechniqueExecution.created_at < end_next,
        )
    )
    if goal.academy_id is not None:
        stmt = stmt.join(User, TechniqueExecution.user_id == User.id).where(
            User.academy_id == goal.academy_id,
        )
    result = await db.scalar(stmt)
    return int(result) if result is not None else 0
