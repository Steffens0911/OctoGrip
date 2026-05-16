from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_time import today_in_app_tz
from app.core.exceptions import AppError
from app.core.role_deps import require_admin_or_academy_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.professor_impact import ProfessorImpactResponse
from app.services.professor_impact_service import get_professor_impact

router = APIRouter()


@router.get("/professor-impact", response_model=ProfessorImpactResponse)
async def me_professor_impact(
    reference_date: date | None = Query(
        None,
        description="Data de referência para calcular a semana ISO. Padrão: hoje.",
    ),
    academy_id: UUID | None = Query(
        None,
        description="Academia a consultar. Obrigatório para administradores; ignorado para professor/gerente (usa a própria academia).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """
    Impacto semanal: alunos alcançados, conclusão por técnica e alunos inativos.
    Professor/gerente vê a própria academia. Admin pode informar academy_id.
    """
    if current_user.role == "administrador":
        if academy_id is None:
            raise AppError(
                "Informe academy_id para visualizar o impacto como administrador.",
                status_code=400,
            )
        resolved_academy_id = academy_id
    else:
        if current_user.academy_id is None:
            raise AppError("Seu usuário não está vinculado a uma academia.", status_code=400)
        resolved_academy_id = current_user.academy_id
        if academy_id is not None:
            verify_academy_access(current_user, str(academy_id))

    ref = reference_date or today_in_app_tz()
    return await get_professor_impact(db, academy_id=resolved_academy_id, reference_date=ref)
