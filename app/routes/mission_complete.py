"""Conclusão por missão: POST /mission_complete (requer autenticação)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import require_aluno_not_frozen
from app.core.exceptions import AppError
from app.database import get_db
from app.models import User
from app.schemas.mission_complete import MissionCompleteRequest, MissionCompleteResponse

router = APIRouter()


@router.post("", response_model=MissionCompleteResponse, status_code=201)
async def mission_complete(
    body: MissionCompleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_aluno_not_frozen),
):
    """
    Conclusão de missão sem adversário.

    Regra do produto: nenhuma conclusão pode ser feita sem adversário.
    O fluxo correto para aluno é criar uma execução em `POST /executions` com `mission_id` + `opponent_id`.
    """
    raise AppError(
        "Conclusão sem adversário não é permitida. Selecione um adversário para registrar a execução.",
        status_code=400,
    )
