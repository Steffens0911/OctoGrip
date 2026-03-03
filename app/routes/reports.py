from datetime import date
from io import StringIO
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.role_deps import require_admin_or_manager, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.metrics import (
    ActiveStudentsReportResponse,
    EngagementReportResponse,
)
from app.services.metrics_service import (
    get_active_students_report,
    get_engagement_report,
)


router = APIRouter()


@router.get("/engagement", response_model=EngagementReportResponse)
async def reports_engagement(
    reference_date: date = Query(
        ...,
        description="Data de referência para calcular semana (últimos 7 dias) e mês.",
    ),
    academy_id: UUID
    | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral (todas as academias).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager),
):
    """
    Relatório de engajamento: % de alunos ativos semanal e mensal.

    - Se `academy_id` for informado, retorna engajamento apenas dessa academia (visão local).
    - Se omitido, retorna engajamento considerando todas as academias (visão geral).
    """
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))

    result = await get_engagement_report(
        db,
        reference_date=reference_date,
        academy_id=academy_id,
    )
    return result


@router.get("/active_students", response_model=ActiveStudentsReportResponse)
async def reports_active_students(
    reference_date: date = Query(
        ...,
        description="Data de referência. A janela considerada é os últimos 7 dias (inclusive).",
    ),
    academy_id: UUID
    | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral (todas as academias).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager),
):
    """
    Relatório detalhado de alunos ativos (lista de alunos) na janela de 7 dias.

    - Ativo = logou pelo menos uma vez (last_login_at) nos últimos 7 dias em relação a `reference_date`.
    - Se `academy_id` for informado, filtra para a academia; senão, considera todas.
    """
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
    academy_id: UUID
    | None = Query(
        None,
        description="Academia para visão local. Se omitido, usa visão geral (todas as academias).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager),
):
    """
    Exporta CSV com alunos ativos na janela de 7 dias.

    Colunas: id, nome, email, graduation, academy_id, academy_name, last_login_at (ISO).
    """
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
        last_login_str = (
            s["last_login_at"].isoformat() if s.get("last_login_at") else ""
        )
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
        headers={
            "Content-Disposition": 'attachment; filename="active_students.csv"'
        },
    )