"""Rotas de Academia (A-03 tema semanal, A-04 ranking)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi.responses import PlainTextResponse

from app.database import get_db
from app.models import Academy, CollectiveGoal

from app.schemas.academy import (
    AcademyCreate,
    AcademyRead,
    AcademyUpdate,
    DifficultiesResponse,
    DifficultyEntry,
    RankingEntry,
    RankingResponse,
    WeeklyReportResponse,
)
from app.schemas.collective_goal import (
    CollectiveGoalCreate,
    CollectiveGoalCurrentResponse,
    CollectiveGoalRead,
)
from app.services.academy_service import (
    create_academy,
    delete_academy,
    get_academy,
    get_academy_difficulties,
    get_academy_ranking,
    get_academy_weekly_report,
    list_academies,
    reset_academy_missions,
    update_academy,
)
from app.services.collective_goal_service import (
    count_executions_for_goal,
    create_goal,
    get_current_goal_for_academy,
    list_goals_for_academy,
)

router = APIRouter()


def _academy_to_read(a: Academy) -> AcademyRead:
    return AcademyRead(
        id=a.id,
        name=a.name,
        slug=a.slug,
        weekly_theme=a.weekly_theme,
        weekly_technique_id=a.weekly_technique_id,
        weekly_technique_name=a.weekly_technique.name if a.weekly_technique else None,
        weekly_technique_2_id=a.weekly_technique_2_id,
        weekly_technique_2_name=a.weekly_technique_2.name if a.weekly_technique_2 else None,
        weekly_technique_3_id=a.weekly_technique_3_id,
        weekly_technique_3_name=a.weekly_technique_3.name if a.weekly_technique_3 else None,
        visible_lesson_id=a.visible_lesson_id,
        visible_lesson_name=a.visible_lesson.title if a.visible_lesson else None,
        weekly_multiplier_1=a.weekly_multiplier_1,
        weekly_multiplier_2=a.weekly_multiplier_2,
        weekly_multiplier_3=a.weekly_multiplier_3,
    )


async def _load_academy_with_rels(db: AsyncSession, academy_id: UUID) -> Academy | None:
    stmt = (
        select(Academy)
        .options(
            selectinload(Academy.weekly_technique),
            selectinload(Academy.weekly_technique_2),
            selectinload(Academy.weekly_technique_3),
            selectinload(Academy.visible_lesson),
        )
        .where(Academy.id == academy_id)
    )
    return (await db.execute(stmt)).scalar_one_or_none()


@router.get("", response_model=list[AcademyRead])
async def academy_list(db: AsyncSession = Depends(get_db)):
    """Lista academias (para painel do professor), com nomes das 3 técnicas semanais."""
    stmt = (
        select(Academy)
        .options(
            selectinload(Academy.weekly_technique),
            selectinload(Academy.weekly_technique_2),
            selectinload(Academy.weekly_technique_3),
            selectinload(Academy.visible_lesson),
        )
        .order_by(Academy.name)
        .limit(100)
    )
    academies = (await db.execute(stmt)).scalars().all()
    return [_academy_to_read(a) for a in academies]


@router.post("", response_model=AcademyRead, status_code=201)
async def academy_create(body: AcademyCreate, db: AsyncSession = Depends(get_db)):
    """Cria uma nova academia."""
    return await create_academy(db, name=body.name, slug=body.slug)


@router.get("/{academy_id}", response_model=AcademyRead)
async def academy_get(academy_id: UUID, db: AsyncSession = Depends(get_db)):
    """Retorna uma academia por ID (com nomes das 3 técnicas semanais se houver)."""
    academy = await _load_academy_with_rels(db, academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return _academy_to_read(academy)


@router.patch("/{academy_id}", response_model=AcademyRead)
async def academy_update(academy_id: UUID, body: AcademyUpdate, db: AsyncSession = Depends(get_db)):
    """Atualiza academia (nome, slug, tema e/ou as 3 missões semanais)."""
    updates = body.model_dump(exclude_unset=True)
    academy = await update_academy(db, academy_id, **updates)
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    await db.refresh(academy)
    academy = await _load_academy_with_rels(db, academy_id)
    return _academy_to_read(academy)


@router.delete("/{academy_id}", status_code=204)
async def academy_delete(academy_id: UUID, db: AsyncSession = Depends(get_db)):
    """Remove uma academia."""
    if not await delete_academy(db, academy_id):
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return None


@router.post("/{academy_id}/reset_missions")
async def academy_reset_missions(academy_id: UUID, db: AsyncSession = Depends(get_db)):
    """Reinicia as missões da academia: limpa conclusões e execuções, preservando pontos."""
    if await get_academy(db, academy_id) is None:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return await reset_academy_missions(db, academy_id)


@router.get("/{academy_id}/difficulties", response_model=DifficultiesResponse)
async def academy_difficulties(academy_id: UUID, limit: int = 50, db: AsyncSession = Depends(get_db)):
    """T-02: Visualização dificuldades."""
    academy = await get_academy(db, academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    entries = await get_academy_difficulties(db, academy_id, limit=min(limit, 100))
    return DifficultiesResponse(
        academy_id=academy_id,
        entries=[DifficultyEntry(**e) for e in entries],
    )


@router.get("/{academy_id}/ranking", response_model=RankingResponse)
async def academy_ranking(academy_id: UUID, period_days: int = 30, limit: int = 50, db: AsyncSession = Depends(get_db)):
    """A-04: Ranking interno da academia."""
    academy = await get_academy(db, academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    entries = await get_academy_ranking(db, academy_id, period_days=min(period_days, 365), limit=min(limit, 100))
    return RankingResponse(
        academy_id=academy_id,
        period_days=min(period_days, 365),
        entries=[RankingEntry(**e) for e in entries],
    )


@router.get("/{academy_id}/report/weekly", response_model=WeeklyReportResponse)
async def academy_report_weekly(academy_id: UUID, year: int | None = None, week: int | None = None, db: AsyncSession = Depends(get_db)):
    """T-03: Relatório semanal da academia."""
    report = await get_academy_weekly_report(db, academy_id, year=year, week=week)
    if not report:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return WeeklyReportResponse(
        academy_id=report["academy_id"],
        week_start=report["week_start"],
        week_end=report["week_end"],
        completions_count=report["completions_count"],
        active_users_count=report["active_users_count"],
        entries=[RankingEntry(**e) for e in report["entries"]],
    )


@router.get("/{academy_id}/report/weekly/csv", response_class=PlainTextResponse)
async def academy_report_weekly_csv(academy_id: UUID, year: int | None = None, week: int | None = None, db: AsyncSession = Depends(get_db)):
    """T-03: Relatório semanal em CSV."""
    report = await get_academy_weekly_report(db, academy_id, year=year, week=week)
    if not report:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    lines = [
        "rank;user_id;name;completions_count",
        *[f"{e['rank']};{e['user_id']};{e.get('name') or ''};{e['completions_count']}" for e in report["entries"]],
    ]
    return "\n".join(lines)


# ---------- Metas coletivas ----------

def _goal_to_read(g) -> CollectiveGoalRead:
    return CollectiveGoalRead(
        id=g.id,
        academy_id=g.academy_id,
        technique_id=g.technique_id,
        target_count=g.target_count,
        start_date=g.start_date,
        end_date=g.end_date,
        created_at=g.created_at,
        technique_name=g.technique.name if g.technique else None,
    )


@router.get("/{academy_id}/collective_goals/current", response_model=CollectiveGoalCurrentResponse | None)
async def collective_goal_current(academy_id: UUID, db: AsyncSession = Depends(get_db)):
    """Meta coletiva da semana atual."""
    goal = await get_current_goal_for_academy(db, academy_id)
    if not goal:
        return None
    current = await count_executions_for_goal(db, goal)
    return CollectiveGoalCurrentResponse(goal=_goal_to_read(goal), current_count=current, target_count=goal.target_count)


@router.get("/{academy_id}/collective_goals", response_model=list[CollectiveGoalRead])
async def collective_goals_list(academy_id: UUID, db: AsyncSession = Depends(get_db)):
    """Lista metas coletivas da academia."""
    goals = await list_goals_for_academy(db, academy_id)
    return [_goal_to_read(g) for g in goals]


@router.post("/{academy_id}/collective_goals", response_model=CollectiveGoalRead, status_code=201)
async def collective_goal_create(academy_id: UUID, body: CollectiveGoalCreate, db: AsyncSession = Depends(get_db)):
    """Cria meta coletiva."""
    if await get_academy(db, academy_id) is None:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    goal = await create_goal(db, academy_id=academy_id, technique_id=body.technique_id, target_count=body.target_count, start_date=body.start_date, end_date=body.end_date)
    await db.refresh(goal)
    stmt = select(CollectiveGoal).options(selectinload(CollectiveGoal.technique)).where(CollectiveGoal.id == goal.id)
    goal = (await db.execute(stmt)).scalar_one_or_none()
    return _goal_to_read(goal)
