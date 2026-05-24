"""Acções administrativas globais: reverter confirmação de execução, anular mission_usage."""

from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.role_deps import require_admin
from app.database import get_db
from app.models import User
from app.schemas.admin_undo import RevertExecutionResponse, VoidMissionUsageResponse
from app.services.execution_service import admin_revert_execution_confirmation
from app.services.mission_usage_service import admin_void_mission_usage

router = APIRouter()


@router.post(
    "/executions/{execution_id}/revert_confirmation",
    response_model=RevertExecutionResponse,
)
async def admin_revert_execution_route(
    execution_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Reverte uma execução **confirmada** para `pending_confirmation`, zera pontos da confirmação
    e recalcula o nível do executor. Regista auditoria.
    """
    row = await admin_revert_execution_confirmation(
        db,
        execution_id=execution_id,
        admin_user_id=current_user.id,
    )
    return RevertExecutionResponse(
        execution_id=str(row.id),
        user_id=str(row.user_id),
        status=row.status,
    )


@router.post(
    "/mission_usages/{usage_id}/void",
    response_model=VoidMissionUsageResponse,
)
async def admin_void_mission_usage_route(
    usage_id: UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """
    Remove um registo `MissionUsage` (conclusão de missão/lição) e recalcula o nível do utilizador.
    Útil para corrigir sync acidental. Regista auditoria (DELETE).
    """
    uid = await admin_void_mission_usage(db, usage_id=usage_id, admin_user_id=_admin.id)
    return VoidMissionUsageResponse(
        mission_usage_id=str(usage_id),
        user_id=str(uid),
    )
