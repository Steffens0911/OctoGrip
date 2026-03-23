"""Endpoints admin: histórico de auditoria e restauração (soft delete / snapshot)."""
from typing import Literal, cast
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.role_deps import require_admin
from app.database import get_db
from app.models import User
from app.schemas.audit import AuditHistoryResponse, AuditLogItem, RestoreResponse
from app.services.audit_service import (
    list_audit_feed,
    list_audit_history,
    resolve_entity_model,
    restore_entity,
)

router = APIRouter()


@router.get("/audit/feed", response_model=AuditHistoryResponse)
async def admin_audit_feed(
    academy_id: UUID | None = Query(
        None,
        description="Filtrar por academia: técnicas/lições/missões/troféus ligados a esta unidade.",
    ),
    entity: str | None = Query(
        None,
        description="Opcional: mission, lesson, technique, trophy.",
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    action: str | None = Query(
        None,
        description="Filtrar por ação: CREATE, UPDATE, DELETE, RESTORE",
    ),
    order: str = Query(
        "desc",
        description="Ordenação por data: desc (padrão) ou asc",
    ),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """Feed global de auditoria com filtros (academia, tipo de entidade, ação)."""
    order_norm = (order or "desc").strip().lower()
    if order_norm not in ("asc", "desc"):
        order_norm = "desc"
    entity_key = (entity or "").strip() or None
    rows, total = await list_audit_feed(
        db,
        academy_id=academy_id,
        entity_api_key=entity_key,
        limit=limit,
        offset=offset,
        action=action,
        order=order_norm,
    )
    order_out: Literal["asc", "desc"] = cast(Literal["asc", "desc"], order_norm)
    return AuditHistoryResponse(
        items=[AuditLogItem.model_validate(r) for r in rows],
        total=total,
        limit=limit,
        offset=offset,
        order=order_out,
    )


@router.get("/audit/{entity}/{entity_id}", response_model=AuditHistoryResponse)
async def admin_audit_history(
    entity: str,
    entity_id: UUID,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    action: str | None = Query(
        None,
        description="Filtrar por ação: CREATE, UPDATE, DELETE, RESTORE",
    ),
    order: str = Query(
        "asc",
        description="Ordenação por data: asc (mais antigo primeiro) ou desc (mais recente primeiro)",
    ),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """Lista alterações da entidade com paginação e ordenação por data."""
    entity_label, _ = resolve_entity_model(entity)
    order_norm = (order or "asc").strip().lower()
    if order_norm not in ("asc", "desc"):
        order_norm = "asc"
    rows, total = await list_audit_history(
        db,
        entity_label=entity_label,
        entity_id=entity_id,
        limit=limit,
        offset=offset,
        action=action,
        order=order_norm,
    )
    order_out: Literal["asc", "desc"] = cast(Literal["asc", "desc"], order_norm)
    return AuditHistoryResponse(
        items=[AuditLogItem.model_validate(r) for r in rows],
        total=total,
        limit=limit,
        offset=offset,
        order=order_out,
    )


@router.post("/restore/{entity}/{entity_id}", response_model=RestoreResponse)
async def admin_restore(
    entity: str,
    entity_id: UUID,
    audit_log_id: UUID | None = Query(
        None,
        description="Opcional: id de um log UPDATE/DELETE; aplica old_data como estado atual.",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Restaura registro soft-deletado (sem audit_log_id) ou reaplica versão anterior (com audit_log_id).
    Apenas administradores.
    """
    result = await restore_entity(
        db,
        entity=entity,
        entity_id=entity_id,
        audit_log_id=audit_log_id,
        user_id=current_user.id,
    )
    return RestoreResponse(**result)
