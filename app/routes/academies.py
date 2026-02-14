"""Rotas de Academia (A-03 tema semanal, A-04 ranking)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models import Academy
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
from app.services.academy_service import (
    create_academy,
    delete_academy,
    get_academy,
    get_academy_difficulties,
    get_academy_ranking,
    get_academy_weekly_report,
    list_academies,
    update_academy,
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
    )


@router.get("", response_model=list[AcademyRead])
def academy_list(db: Session = Depends(get_db)):
    """Lista academias (para painel do professor), com nomes das 3 técnicas semanais."""
    academies = (
        db.query(Academy)
        .options(
            joinedload(Academy.weekly_technique),
            joinedload(Academy.weekly_technique_2),
            joinedload(Academy.weekly_technique_3),
        )
        .order_by(Academy.name)
        .limit(100)
        .all()
    )
    return [_academy_to_read(a) for a in academies]


@router.post("", response_model=AcademyRead, status_code=201)
def academy_create(body: AcademyCreate, db: Session = Depends(get_db)):
    """Cria uma nova academia."""
    return create_academy(db, name=body.name, slug=body.slug)


@router.get("/{academy_id}", response_model=AcademyRead)
def academy_get(
    academy_id: UUID,
    db: Session = Depends(get_db),
):
    """Retorna uma academia por ID (com nomes das 3 técnicas semanais se houver)."""
    academy = (
        db.query(Academy)
        .options(
            joinedload(Academy.weekly_technique),
            joinedload(Academy.weekly_technique_2),
            joinedload(Academy.weekly_technique_3),
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
):
    """Atualiza academia (nome, slug, tema e/ou as 3 missões semanais). Campos omitidos não são alterados; null limpa a técnica."""
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
        )
        .filter(Academy.id == academy_id)
        .first()
    )
    return _academy_to_read(academy)


@router.delete("/{academy_id}", status_code=204)
def academy_delete(academy_id: UUID, db: Session = Depends(get_db)):
    """Remove uma academia."""
    if not delete_academy(db, academy_id):
        raise HTTPException(status_code=404, detail="Academia não encontrada.")
    return None


@router.get("/{academy_id}/difficulties", response_model=DifficultiesResponse)
def academy_difficulties(
    academy_id: UUID,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    """T-02: Visualização dificuldades — posições mais marcadas pela academia."""
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
):
    """A-04: Ranking interno da academia (missões concluídas nos últimos N dias)."""
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
):
    """T-03: Export simples — relatório semanal da academia (JSON)."""
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
):
    """T-03: Export simples — relatório semanal em CSV."""
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
