"""Rotas de execuções de técnica (gamificação): criar, pendentes, confirmar."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.execution import (
    ExecutionConfirmRequest,
    ExecutionConfirmResponse,
    ExecutionCreate,
    ExecutionCreateResponse,
    ExecutionRead,
    ExecutionRejectRequest,
    ExecutionRejectResponse,
)
from app.services.execution_service import (
    confirm_execution,
    create_execution,
    list_my_executions,
    list_pending_confirmations,
    reject_execution,
)

router = APIRouter()


def _execution_to_read(execution) -> ExecutionRead:
    technique_name = None
    if execution.mission and execution.mission.technique:
        technique_name = execution.mission.technique.name
    elif execution.lesson and execution.lesson.technique:
        technique_name = execution.lesson.technique.name
    return ExecutionRead(
        id=execution.id,
        user_id=execution.user_id,
        mission_id=execution.mission_id,
        lesson_id=execution.lesson_id,
        opponent_id=execution.opponent_id,
        usage_type=execution.usage_type,
        status=execution.status,
        outcome=execution.outcome,
        points_awarded=execution.points_awarded,
        created_at=execution.created_at,
        confirmed_at=execution.confirmed_at,
        confirmed_by=execution.confirmed_by,
        executor_name=execution.user.name if execution.user else None,
        opponent_name=execution.opponent.name if execution.opponent else None,
        technique_name=technique_name,
    )


@router.post("", response_model=ExecutionCreateResponse, status_code=201)
def execution_create(body: ExecutionCreate, db: Session = Depends(get_db)):
    """Registra que o usuário aplicou a técnica no adversário. Aguarda confirmação do adversário."""
    execution = create_execution(
        db,
        user_id=body.user_id,
        opponent_id=body.opponent_id,
        usage_type=body.usage_type,
        mission_id=body.mission_id,
        lesson_id=body.lesson_id,
    )
    opponent_name = execution.opponent.name if execution.opponent else "Adversário"
    return ExecutionCreateResponse(
        id=execution.id,
        status="pending_confirmation",
        message=f"Aguardando confirmação de {opponent_name}.",
    )


@router.get("/pending_confirmations", response_model=list[ExecutionRead])
def execution_pending_confirmations(
    user_id: UUID = Query(..., description="ID do adversário (quem deve confirmar)"),
    db: Session = Depends(get_db),
):
    """Lista execuções pendentes de confirmação para o usuário (ele é o adversário)."""
    executions = list_pending_confirmations(db, opponent_id=user_id)
    return [_execution_to_read(e) for e in executions]


@router.post("/{execution_id}/confirm", response_model=ExecutionConfirmResponse)
def execution_confirm(
    execution_id: UUID,
    body: ExecutionConfirmRequest,
    db: Session = Depends(get_db),
):
    """Confirma a execução (apenas o adversário). outcome: attempted_correctly | executed_successfully."""
    execution = confirm_execution(
        db,
        execution_id=execution_id,
        outcome=body.outcome,
        confirmed_by_user_id=body.user_id,
    )
    if not execution.points_awarded:
        execution.points_awarded = 0
    return ExecutionConfirmResponse(
        id=execution.id,
        status="confirmed",
        outcome=execution.outcome or "",
        points_awarded=execution.points_awarded,
        confirmed_at=execution.confirmed_at,
    )


@router.post("/{execution_id}/reject", response_model=ExecutionRejectResponse)
def execution_reject(
    execution_id: UUID,
    body: ExecutionRejectRequest,
    db: Session = Depends(get_db),
):
    """Recusa a execução (apenas o adversário). reason=dont_remember notifica que não aceitou a posição."""
    execution = reject_execution(
        db,
        execution_id=execution_id,
        rejected_by_user_id=body.user_id,
        reason=body.reason,
    )
    return ExecutionRejectResponse(id=execution.id, status=execution.status)


@router.get("/my_executions", response_model=list[ExecutionRead])
def execution_my_executions(
    user_id: UUID = Query(..., description="ID do executor (quem aplicou a técnica)"),
    db: Session = Depends(get_db),
):
    """Lista execuções criadas pelo usuário (executor), todos os status."""
    executions = list_my_executions(db, user_id=user_id)
    return [_execution_to_read(e) for e in executions]
