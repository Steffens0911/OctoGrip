"""Rotas de Academia (A-03 tema semanal, A-04 ranking)."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from fastapi.responses import PlainTextResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AcademyNotFoundError, ForbiddenError
from app.core.role_deps import require_admin, require_admin_or_academy_access, verify_academy_access
from app.database import get_db
from app.models import Academy, CollectiveGoal, User
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


async def _load_academy_with_relations(db: AsyncSession, academy_id: UUID) -> Academy:
    result = await db.execute(
        select(Academy)
        .options(
            selectinload(Academy.weekly_technique),
            selectinload(Academy.weekly_technique_2),
            selectinload(Academy.weekly_technique_3),
            selectinload(Academy.visible_lesson),
        )
        .where(Academy.id == academy_id)
    )
    academy = result.scalar_one_or_none()
    if not academy:
        raise AcademyNotFoundError()
    return academy


@router.get("", response_model=list[AcademyRead])
async def academy_list(
    db: AsyncSession = Depends(get_db),
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(100, ge=1, le=500, description="Limite de resultados"),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Lista academias com paginação."""
    stmt = (
        select(Academy)
        .options(
            selectinload(Academy.weekly_technique),
            selectinload(Academy.weekly_technique_2),
            selectinload(Academy.weekly_technique_3),
            selectinload(Academy.visible_lesson),
        )
        .order_by(Academy.name)
    )
    if current_user.role == "administrador":
        result = await db.execute(stmt.offset(offset).limit(limit))
        academies = result.scalars().all()
    else:
        if current_user.academy_id is None:
            academies = []
        else:
            result = await db.execute(stmt.where(Academy.id == current_user.academy_id))
            academies = result.scalars().all()
    return [_academy_to_read(a) for a in academies]


@router.post("", response_model=AcademyRead, status_code=201)
async def academy_create(
    body: AcademyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Cria uma nova academia. Apenas administradores."""
    return await create_academy(db, name=body.name, slug=body.slug)


@router.get("/{academy_id}", response_model=AcademyRead)
async def academy_get(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Retorna uma academia por ID."""
    if current_user.role != "administrador" and current_user.academy_id != academy_id:
        raise ForbiddenError("Acesso negado. Você só pode acessar a academia à qual está vinculado.")
    academy = await _load_academy_with_relations(db, academy_id)
    return _academy_to_read(academy)


@router.patch("/{academy_id}", response_model=AcademyRead)
async def academy_update(
    academy_id: UUID,
    body: AcademyUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Atualiza academia. Apenas administradores."""
    updates = body.model_dump(exclude_unset=True)
    academy = await update_academy(db, academy_id, **updates)
    if not academy:
        raise AcademyNotFoundError()
    await db.refresh(academy)
    academy = await _load_academy_with_relations(db, academy_id)
    return _academy_to_read(academy)


@router.delete("/{academy_id}", status_code=204)
async def academy_delete(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Remove uma academia. Apenas administradores."""
    if not await delete_academy(db, academy_id):
        raise AcademyNotFoundError()
    return None


@router.post("/{academy_id}/reset_missions")
async def academy_reset_missions_route(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Reinicia as missões da academia."""
    academy = await get_academy(db, academy_id)
    if academy is None:
        raise AcademyNotFoundError()
    verify_academy_access(current_user, str(academy_id))
    return await reset_academy_missions(db, academy_id)


@router.get("/{academy_id}/difficulties", response_model=DifficultiesResponse)
async def academy_difficulties(
    academy_id: UUID,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """T-02: Visualização dificuldades."""
    academy = await get_academy(db, academy_id)
    if not academy:
        raise AcademyNotFoundError()
    verify_academy_access(current_user, str(academy_id))
    entries = await get_academy_difficulties(db, academy_id, limit=min(limit, 100))
    return DifficultiesResponse(
        academy_id=academy_id,
        entries=[DifficultyEntry(**e) for e in entries],
    )


@router.get("/{academy_id}/ranking", response_model=RankingResponse)
async def academy_ranking(
    academy_id: UUID,
    period_days: int = 30,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """A-04: Ranking interno da academia."""
    academy = await get_academy(db, academy_id)
    if not academy:
        raise AcademyNotFoundError()
    verify_academy_access(current_user, str(academy_id))
    entries = await get_academy_ranking(
        db,
        academy_id,
        period_days=min(period_days, 365),
        limit=min(limit, 100),
    )
    return RankingResponse(
        academy_id=academy_id,
        period_days=min(period_days, 365),
        entries=[RankingEntry(**e) for e in entries],
    )


@router.get("/{academy_id}/report/weekly", response_model=WeeklyReportResponse)
async def academy_report_weekly(
    academy_id: UUID,
    year: int | None = None,
    week: int | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """T-03: Relatório semanal."""
    verify_academy_access(current_user, str(academy_id))
    report = await get_academy_weekly_report(db, academy_id, year=year, week=week)
    if not report:
        raise AcademyNotFoundError()
    return WeeklyReportResponse(
        academy_id=report["academy_id"],
        week_start=report["week_start"],
        week_end=report["week_end"],
        completions_count=report["completions_count"],
        active_users_count=report["active_users_count"],
        entries=[RankingEntry(**e) for e in report["entries"]],
    )


@router.get("/{academy_id}/report/weekly/csv", response_class=PlainTextResponse)
async def academy_report_weekly_csv(
    academy_id: UUID,
    year: int | None = None,
    week: int | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """T-03: Relatório semanal em CSV."""
    verify_academy_access(current_user, str(academy_id))
    report = await get_academy_weekly_report(db, academy_id, year=year, week=week)
    if not report:
        raise AcademyNotFoundError()
    lines = [
        "rank;user_id;name;completions_count",
        *[
            f"{e['rank']};{e['user_id']};{e.get('name') or ''};{e['completions_count']}"
            for e in report["entries"]
        ],
    ]
    return "\n".join(lines)


# ---------- Metas coletivas (gamificação) ----------


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
async def collective_goal_current(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Meta coletiva da semana atual."""
    verify_academy_access(current_user, str(academy_id))
    goal = await get_current_goal_for_academy(db, academy_id)
    if not goal:
        return None
    current = await count_executions_for_goal(db, goal)
    return CollectiveGoalCurrentResponse(
        goal=_goal_to_read(goal),
        current_count=current,
        target_count=goal.target_count,
    )


@router.get("/{academy_id}/collective_goals", response_model=list[CollectiveGoalRead])
async def collective_goals_list(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Lista metas coletivas da academia."""
    verify_academy_access(current_user, str(academy_id))
    goals = await list_goals_for_academy(db, academy_id)
    return [_goal_to_read(g) for g in goals]


@router.post("/{academy_id}/collective_goals", response_model=CollectiveGoalRead, status_code=201)
async def collective_goal_create(
    academy_id: UUID,
    body: CollectiveGoalCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Cria meta coletiva."""
    if await get_academy(db, academy_id) is None:
        raise AcademyNotFoundError()
    verify_academy_access(current_user, str(academy_id))
    goal = await create_goal(
        db,
        academy_id=academy_id,
        technique_id=body.technique_id,
        target_count=body.target_count,
        start_date=body.start_date,
        end_date=body.end_date,
    )
    await db.refresh(goal)
    result = await db.execute(
        select(CollectiveGoal)
        .options(selectinload(CollectiveGoal.technique))
        .where(CollectiveGoal.id == goal.id)
    )
    goal = result.scalar_one_or_none()
    return _goal_to_read(goal)
