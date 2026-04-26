from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.auth_deps import get_current_user, require_aluno_not_frozen
from app.core.exceptions import AppError
from app.models import User
from app.schemas.lesson_complete import (
    LessonCompleteRequest,
    LessonCompleteResponse,
    LessonCompleteStatusResponse,
)
from app.services.lesson_complete_service import complete_lesson, is_lesson_completed

router = APIRouter()


@router.get("/status", response_model=LessonCompleteStatusResponse)
async def lesson_complete_status(
    lesson_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Indica se a lição já foi concluída pelo usuário logado (para exibir botão desabilitado)."""
    completed = await is_lesson_completed(db, current_user.id, lesson_id)
    return LessonCompleteStatusResponse(completed=completed)


@router.post("", response_model=LessonCompleteResponse, status_code=201)
async def lesson_complete(
    body: LessonCompleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_aluno_not_frozen),
):
    """
    Conclusão de lição sem adversário.

    Regra do produto: nenhuma conclusão pode ser feita sem adversário.
    O fluxo correto para aluno é criar uma execução em `POST /executions` com `lesson_id` + `opponent_id`.
    """
    raise AppError(
        "Conclusão sem adversário não é permitida. Selecione um adversário para registrar a execução.",
        status_code=400,
    )
