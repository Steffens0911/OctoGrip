"""Rotas de Academia (A-03 tema semanal, A-04 ranking)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from app.core.role_deps import require_admin, require_admin_or_academy_access
from app.database import get_db
from app.models import Academy, CollectiveGoal, User
from fastapi.responses import PlainTextResponse

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


@router.get("", response_model=list[AcademyRead])
def academy_list(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Lista academias (para painel). Admin vê todas; professor/gerente/supervisor só a academia vinculada."""
    base_query = (
        db.query(Academy)
        .options(
            joinedload(Academy.weekly_technique),
            joinedload(Academy.weekly_technique_2),
            joinedload(Academy.weekly_technique_3),
            joinedload(Academy.visible_lesson),
        )
        .order_by(Academy.name)
    )
    if current_user.role == "administrador":
        academies = base_query.limit(100).all()
    else:
        if current_user.academy_id is None:
            academies = []
        else:
            academies = base_query.filter(Academy.id == current_user.academy_id).all()
    return [_academy_to_read(a) for a in academies]


@router.post("", response_model=AcademyRead, status_code=201)
def academy_create(
    body: AcademyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Cria uma nova academia. Apenas administradores."""
    return create_academy(db, name=body.name, slug=body.slug)


@router.get("/{academy_id}", response_model=AcademyRead)
def academy_get(
    academy_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Retorna uma academia por ID. Admin vê qualquer uma; professor/gerente/supervisor só a própria."""
    if current_user.role != "administrador" and current_user.academy_id != academy_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Você só pode acessar a academia à qual está vinculado.",
        )
    academy = (
        db.query(Academy)
        .options(
            joinedload(Academy.weekly_technique),
            joinedload(Academy.weekly_technique_2),
            joinedload(Academy.weekly_technique_3),
            joinedload(Academy.visible_lesson),
        )
        .filter(Academy.id == academy_id)
        .first()
    )
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return _academy_to_read(academy)


@router.patch("/{academy_id}", response_model=AcademyRead)
def academy_update(
    academy_id: UUID,
    body: AcademyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Atualiza academia (nome, slug, tema e/ou as 3 missões semanais). Campos omitidos não são alterados; null limpa a técnica. Apenas administradores."""
    updates = body.model_dump(exclude_unset=True)
    academy = update_academy(db, academy_id, **updates)
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    db.refresh(academy)
    academy = (
        db.query(Academy)
        .options(
            joinedload(Academy.weekly_technique),
            joinedload(Academy.weekly_technique_2),
            joinedload(Academy.weekly_technique_3),
            joinedload(Academy.visible_lesson),
        )
        .filter(Academy.id == academy_id)
        .first()
    )
    return _academy_to_read(academy)


@router.delete("/{academy_id}", status_code=204)
def academy_delete(
    academy_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Remove uma academia. Apenas administradores."""
    if not delete_academy(db, academy_id):
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return None


@router.post("/{academy_id}/reset_missions")
def academy_reset_missions(
    academy_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Reinicia as missões da academia: limpa conclusões e execuções, preservando pontos em points_adjustment. Admin, gerente ou professor."""
    if get_academy(db, academy_id) is None:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return reset_academy_missions(db, academy_id)


@router.get("/{academy_id}/difficulties", response_model=DifficultiesResponse)
def academy_difficulties(
    academy_id: UUID,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """T-02: Visualização dificuldades — posições mais marcadas pela academia. Admin, gerente ou professor."""
    academy = get_academy(db, academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    entries = get_academy_difficulties(db, academy_id, limit=min(limit, 100))
    return DifficultiesResponse(
        academy_id=academy_id,
        entries=[DifficultyEntry(**e) for e in entries],
    )


@router.get("/{academy_id}/ranking", response_model=RankingResponse)
def academy_ranking(
    academy_id: UUID,
    period_days: int = 30,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """A-04: Ranking interno da academia (missões concluídas nos últimos N dias). Admin, gerente ou professor."""
    academy = get_academy(db, academy_id)
    if not academy:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    entries = get_academy_ranking(
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
def academy_report_weekly(
    academy_id: UUID,
    year: int | None = None,
    week: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """T-03: Export simples — relatório semanal da academia (JSON). Admin, gerente ou professor."""
    report = get_academy_weekly_report(db, academy_id, year=year, week=week)
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
def academy_report_weekly_csv(
    academy_id: UUID,
    year: int | None = None,
    week: int | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """T-03: Export simples — relatório semanal em CSV. Admin, gerente ou professor."""
    report = get_academy_weekly_report(db, academy_id, year=year, week=week)
    if not report:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
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
def collective_goal_current(
    academy_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Meta coletiva da semana atual para a academia (com progresso). Admin, gerente ou professor."""
    goal = get_current_goal_for_academy(db, academy_id)
    if not goal:
        return None
    current = count_executions_for_goal(db, goal)
    return CollectiveGoalCurrentResponse(
        goal=_goal_to_read(goal),
        current_count=current,
        target_count=goal.target_count,
    )


@router.get("/{academy_id}/collective_goals", response_model=list[CollectiveGoalRead])
def collective_goals_list(
    academy_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Lista metas coletivas da academia. Admin, gerente ou professor."""
    goals = list_goals_for_academy(db, academy_id)
    return [_goal_to_read(g) for g in goals]


@router.post("/{academy_id}/collective_goals", response_model=CollectiveGoalRead, status_code=201)
def collective_goal_create(
    academy_id: UUID,
    body: CollectiveGoalCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Cria meta coletiva. Admin, gerente ou professor."""
    if get_academy(db, academy_id) is None:
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    goal = create_goal(
        db,
        academy_id=academy_id,
        technique_id=body.technique_id,
        target_count=body.target_count,
        start_date=body.start_date,
        end_date=body.end_date,
    )
    db.refresh(goal)
    goal = (
        db.query(CollectiveGoal)
        .options(joinedload(CollectiveGoal.technique))
        .filter(CollectiveGoal.id == goal.id)
        .first()
    )
    return _goal_to_read(goal)
