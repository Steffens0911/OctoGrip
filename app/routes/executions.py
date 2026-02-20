"""Rotas de execuções de técnica (gamificação): criar, pendentes, confirmar."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.execution import (
    ExecutionConfirmRequest, ExecutionConfirmResponse, ExecutionCreate,
    ExecutionCreateResponse, ExecutionRead, ExecutionRejectRequest, ExecutionRejectResponse,
)
from app.services.execution_service import (
    confirm_execution, count_pending_confirmations, create_execution,
    list_my_executions, list_pending_confirmations, reject_execution,
)

router = APIRouter()


def _execution_to_read(execution) -> ExecutionRead:
    technique_name = None
    if execution.technique:
        technique_name = execution.technique.name
    elif execution.mission and execution.mission.technique:
        technique_name = execution.mission.technique.name
    elif execution.lesson and execution.lesson.technique:
        technique_name = execution.lesson.technique.name
    return ExecutionRead(
        id=execution.id, user_id=execution.user_id, mission_id=execution.mission_id,
        lesson_id=execution.lesson_id, opponent_id=execution.opponent_id,
        usage_type=execution.usage_type, status=execution.status, outcome=execution.outcome,
        points_awarded=execution.points_awarded, created_at=execution.created_at,
        confirmed_at=execution.confirmed_at, confirmed_by=execution.confirmed_by,
        executor_name=execution.user.name if execution.user else None,
        executor_graduation=execution.user.graduation if execution.user else None,
        opponent_name=execution.opponent.name if execution.opponent else None,
        opponent_graduation=execution.opponent.graduation if execution.opponent else None,
        technique_name=technique_name,
    )


@router.post("", response_model=ExecutionCreateResponse, status_code=201)
async def execution_create(body: ExecutionCreate, db: AsyncSession = Depends(get_db)):
    execution = await create_execution(
        db, user_id=body.user_id, opponent_id=body.opponent_id, usage_type=body.usage_type,
        mission_id=body.mission_id, lesson_id=body.lesson_id, technique_id=body.technique_id, academy_id=body.academy_id,
    )
    opponent_name = execution.opponent.name if execution.opponent else "Adversário"
    return ExecutionCreateResponse(id=execution.id, status="pending_confirmation", message=f"Aguardando confirmação de {opponent_name}.")


@router.get("/pending_confirmations/count")
async def execution_pending_confirmations_count(user_id: UUID = Query(...), db: AsyncSession = Depends(get_db)):
    return {"count": await count_pending_confirmations(db, opponent_id=user_id)}


@router.get("/pending_confirmations", response_model=list[ExecutionRead])
async def execution_pending_confirmations(user_id: UUID = Query(...), db: AsyncSession = Depends(get_db)):
    executions = await list_pending_confirmations(db, opponent_id=user_id)
    return [_execution_to_read(e) for e in executions]


@router.post("/{execution_id}/confirm", response_model=ExecutionConfirmResponse)
async def execution_confirm(execution_id: UUID, body: ExecutionConfirmRequest, db: AsyncSession = Depends(get_db)):
    execution = await confirm_execution(db, execution_id=execution_id, outcome=body.outcome, confirmed_by_user_id=body.user_id)
    if not execution.points_awarded:
        execution.points_awarded = 0
    return ExecutionConfirmResponse(
        id=execution.id, status="confirmed", outcome=execution.outcome or "",
        points_awarded=execution.points_awarded, confirmed_at=execution.confirmed_at,
    )


@router.post("/{execution_id}/reject", response_model=ExecutionRejectResponse)
async def execution_reject(execution_id: UUID, body: ExecutionRejectRequest, db: AsyncSession = Depends(get_db)):
    execution = await reject_execution(db, execution_id=execution_id, rejected_by_user_id=body.user_id, reason=body.reason)
    return ExecutionRejectResponse(id=execution.id, status=execution.status)


@router.get("/my_executions", response_model=list[ExecutionRead])
async def execution_my_executions(user_id: UUID = Query(...), db: AsyncSession = Depends(get_db)):
    executions = await list_my_executions(db, user_id=user_id)
    return [_execution_to_read(e) for e in executions]
