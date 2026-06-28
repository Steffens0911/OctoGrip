from datetime import date, timedelta
from io import StringIO
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_time import combine_local_date_start_utc, today_in_app_tz
from app.core.exceptions import AppError, ForbiddenError
from app.core.role_deps import require_admin_manager_or_supervisor, require_write_access, verify_academy_access
from app.database import get_db
from app.models import AttendanceRecord, AttendanceSession, User
from app.schemas.metrics import (
    ActiveStudentsReportResponse,
    EngagementReportResponse,
    MissionCompletionReportResponse,
    StudentsAttentionReportResponse,
    TechniqueExecutionSummaryResponse,
    WeeklyPanelLoginsReportResponse,
)
from app.services.metrics_service import (
    get_active_students_report,
    get_engagement_report,
    get_mission_completion_report,
    get_students_attention_report,
    get_technique_execution_summary,
    get_weekly_panel_logins_report,
)


class PunctualityStudentEntry(BaseModel):
    student_id: UUID
    name: str | None
    punctuality_streak: int
    punctuality_streak_best: int
    punctual_count: int
    late_count: int
    total_checkins: int
    punctuality_pct: float


class PunctualityReportResponse(BaseModel):
    academy_id: UUID
    days: int
    students: list[PunctualityStudentEntry]

router = APIRouter()

_MAX_REPORT_DATE_RANGE_DAYS = 366


def _validate_inclusive_date_range(start: date, end: date) -> None:
    if start > end:
        raise AppError("start_date deve ser anterior ou igual a end_date.", status_code=400)
    if (end - start).days + 1 > _MAX_REPORT_DATE_RANGE_DAYS:
        raise AppError(
            f"Intervalo máximo de {_MAX_REPORT_DATE_RANGE_DAYS} dias.",
            status_code=400,
        )


@router.get("/engagement", response_model=EngagementReportResponse)
async def reports_engagement(
    reference_date: date = Query(
        ...,
        description="Data de referência para calcular semana (últimos 7 dias) e mês.",
    ),
    academy_id: UUID | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral (todas as academias).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """
    Relatório de engajamento: % de alunos ativos semanal e mensal.

    - Se `academy_id` for informado, retorna engajamento apenas dessa academia (visão local).
    - Se omitido, retorna engajamento considerando todas as academias (visão geral).
    """
    if current_user.role == "supervisor" and academy_id is None:
        raise ForbiddenError("Supervisores devem informar academy_id (visão por academia).")
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))

    result = await get_engagement_report(
        db,
        reference_date=reference_date,
        academy_id=academy_id,
    )
    return result


@router.get("/weekly_panel_logins", response_model=WeeklyPanelLoginsReportResponse)
async def reports_weekly_panel_logins(
    reference_date: date | None = Query(
        None,
        description="Data de referência para semana ISO (ignorada se start_date e end_date forem informados).",
    ),
    start_date: date | None = Query(
        None,
        description="Início do intervalo (inclusive). Exige end_date.",
    ),
    end_date: date | None = Query(
        None,
        description="Fim do intervalo (inclusive). Exige start_date.",
    ),
    academy_id: UUID | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral (todas as academias).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """
    Relatório de logins (staff e alunos), com base em user_login_days.

    - Intervalo customizado: `start_date` e `end_date` (inclusive).
    - Caso contrário: semana ISO que contém `reference_date` (default: hoje).

    - Se `academy_id` for informado, retorna apenas usuários vinculados à academia.
    - Se omitido, retorna visão global.
    """
    if current_user.role == "supervisor" and academy_id is None:
        raise ForbiddenError("Supervisores devem informar academy_id (visão por academia).")
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))

    if (start_date is None) ^ (end_date is None):
        raise AppError("Informe start_date e end_date juntos, ou omita ambos.", status_code=400)
    if start_date is not None and end_date is not None:
        _validate_inclusive_date_range(start_date, end_date)
        result = await get_weekly_panel_logins_report(
            db,
            reference_date=None,
            academy_id=academy_id,
            range_start=start_date,
            range_end=end_date,
        )
    else:
        ref = reference_date if reference_date is not None else today_in_app_tz()
        result = await get_weekly_panel_logins_report(
            db,
            reference_date=ref,
            academy_id=academy_id,
        )
    return result


@router.get("/technique_execution_summary", response_model=TechniqueExecutionSummaryResponse)
async def reports_technique_execution_summary(
    academy_id: UUID | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral.",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """Resumo de execuções de técnicas confirmadas: planejadas (before_training) vs naturais (after_training)."""
    if current_user.role == "supervisor" and academy_id is None:
        raise ForbiddenError("Supervisores devem informar academy_id.")
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))
    return await get_technique_execution_summary(db, academy_id=academy_id)


@router.get("/students_attention", response_model=StudentsAttentionReportResponse)
async def reports_students_attention(
    academy_id: UUID | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral.",
    ),
    limit: int = Query(
        20,
        ge=1,
        le=100,
        description="Quantidade máxima de alunos retornados (padrão 20).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """
    Alunos que há mais tempo não aparecem em nenhuma aula.
    Ordenados por última presença (mais antiga primeiro). Alunos sem nenhuma presença aparecem primeiro.
    """
    if current_user.role == "supervisor" and academy_id is None:
        raise ForbiddenError("Supervisores devem informar academy_id (visão por academia).")
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))

    return await get_students_attention_report(db, academy_id=academy_id, limit=limit)


@router.get("/mission_completion", response_model=MissionCompletionReportResponse)
async def reports_mission_completion(
    from_date: date = Query(
        ...,
        description="Início do período (inclusive).",
    ),
    to_date: date = Query(
        ...,
        description="Fim do período (inclusive).",
    ),
    academy_id: UUID | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral.",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """
    Taxa de conclusão de missões: % de alunos que concluíram ≥1 missão no período.
    """
    if current_user.role == "supervisor" and academy_id is None:
        raise ForbiddenError("Supervisores devem informar academy_id (visão por academia).")
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))
    _validate_inclusive_date_range(from_date, to_date)
    return await get_mission_completion_report(
        db,
        from_date=from_date,
        to_date=to_date,
        academy_id=academy_id,
    )


@router.get("/active_students", response_model=ActiveStudentsReportResponse)
async def reports_active_students(
    reference_date: date = Query(
        ...,
        description="Data de referência. A janela considerada é os últimos 7 dias (inclusive).",
    ),
    academy_id: UUID | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral (todas as academias).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """
    Relatório detalhado de alunos ativos (lista de alunos) na janela de 7 dias.

    - Ativo = logou pelo menos uma vez (last_login_at) nos últimos 7 dias em relação a `reference_date`.
    - Se `academy_id` for informado, filtra para a academia; senão, considera todas.
    """
    if current_user.role == "supervisor" and academy_id is None:
        raise ForbiddenError("Supervisores devem informar academy_id (visão por academia).")
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))

    result = await get_active_students_report(
        db,
        reference_date=reference_date,
        academy_id=academy_id,
    )
    return result


@router.get("/active_students/csv")
async def reports_active_students_csv(
    reference_date: date = Query(
        ...,
        description="Data de referência. A janela considerada é os últimos 7 dias (inclusive).",
    ),
    academy_id: UUID | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral (todas as academias).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_manager_or_supervisor),
):
    """
    Exporta CSV com alunos ativos na janela de 7 dias.

    Colunas: id, nome, email, graduation, academy_id, academy_name, last_login_at (ISO).
    """
    if current_user.role == "supervisor" and academy_id is None:
        raise ForbiddenError("Supervisores devem informar academy_id (visão por academia).")
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))

    report = await get_active_students_report(
        db,
        reference_date=reference_date,
        academy_id=academy_id,
    )

    output = StringIO()
    output.write(
        "id,name,email,graduation,academy_id,academy_name,last_login_at\n",
    )
    for s in report["students"]:
        last_login_str = s["last_login_at"].isoformat() if s.get("last_login_at") else ""
        row = [
            s.get("id") or "",
            (s.get("name") or "").replace(",", " "),
            s.get("email") or "",
            (s.get("graduation") or "").replace(",", " "),
            s.get("academy_id") or "",
            (s.get("academy_name") or "").replace(",", " "),
            last_login_str,
        ]
        output.write(",".join(row) + "\n")

    csv_content = output.getvalue()
    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="active_students.csv"'},
    )


@router.get("/punctuality", response_model=PunctualityReportResponse)
async def reports_punctuality(
    academy_id: UUID | None = Query(default=None),
    days: int = Query(default=30, ge=7, le=90, description="Janela de análise em dias."),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """
    Relatório de pontualidade por aluno nos últimos N dias.

    Retorna contagem de check-ins pontuais/atrasados e o streak atual de cada aluno.
    Acesso: professor, gerente ou admin.
    """
    target_academy_id = academy_id or current_user.academy_id
    if not target_academy_id:
        raise AppError("academy_id é obrigatório para este utilizador.", status_code=400)
    verify_academy_access(current_user, str(target_academy_id))

    cutoff_dt = combine_local_date_start_utc(today_in_app_tz() - timedelta(days=days))

    # Alunos da academia com ao menos um check-in com was_punctual definido no período
    rows = (
        await db.execute(
            select(
                AttendanceRecord.user_id,
                func.count(AttendanceRecord.id).filter(AttendanceRecord.was_punctual.is_(True)).label("punctual_count"),
                func.count(AttendanceRecord.id).label("total_checkins"),
            )
            .join(AttendanceSession, AttendanceRecord.session_id == AttendanceSession.id)
            .where(
                AttendanceSession.academy_id == target_academy_id,
                AttendanceRecord.was_punctual.is_not(None),
                AttendanceSession.starts_at >= cutoff_dt,
            )
            .group_by(AttendanceRecord.user_id)
        )
    ).all()

    if not rows:
        return PunctualityReportResponse(
            academy_id=target_academy_id,
            days=days,
            students=[],
        )

    user_ids = [r[0] for r in rows]
    users = (
        await db.execute(
            select(User).where(User.id.in_(user_ids), User.role == "aluno").order_by(User.name.asc().nulls_last())
        )
    ).scalars().all()
    user_map = {u.id: u for u in users}

    entries: list[PunctualityStudentEntry] = []
    for row in rows:
        uid, punctual_count_raw, total = row
        user = user_map.get(uid)
        if not user:
            continue
        punctual_count = int(punctual_count_raw or 0)
        total_checkins = int(total or 0)
        late_count = total_checkins - punctual_count
        pct = round(punctual_count / total_checkins * 100, 1) if total_checkins else 0.0
        entries.append(
            PunctualityStudentEntry(
                student_id=uid,
                name=user.name,
                punctuality_streak=user.punctuality_streak,
                punctuality_streak_best=user.punctuality_streak_best,
                punctual_count=punctual_count,
                late_count=late_count,
                total_checkins=total_checkins,
                punctuality_pct=pct,
            )
        )

    entries.sort(key=lambda e: -e.punctuality_pct)

    return PunctualityReportResponse(
        academy_id=target_academy_id,
        days=days,
        students=entries,
    )
