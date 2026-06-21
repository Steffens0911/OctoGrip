"""Rotas para treinos lançados pelo professor e templates (favoritos)."""

from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.role_deps import require_read_access, require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.training_session import (
    PreCheckinRead,
    PreCheckinStatusRead,
    TrainingSessionCreate,
    TrainingSessionRead,
    TrainingSessionSummaryRead,
    TrainingSessionUpdate,
    TrainingTemplateCreate,
    TrainingTemplateRead,
    TrainingTemplateUpdate,
)
from app.services import pre_checkin_service
from app.services.training_session_service import (
    close_session,
    create_session,
    create_template,
    delete_session,
    delete_template,
    get_session,
    get_session_summary,
    list_sessions,
    list_templates,
    open_session,
    update_session,
    update_template,
)

router = APIRouter()


async def _session_read(db: AsyncSession, s) -> TrainingSessionRead:
    from app.services.pre_checkin_service import count_confirmed
    count = await count_confirmed(db, s.id)
    return TrainingSessionRead(
        id=s.id,
        academy_id=s.academy_id,
        created_by_user_id=s.created_by_user_id,
        template_id=s.template_id,
        class_date=s.class_date,
        start_time=s.start_time,
        tolerance_minutes=s.tolerance_minutes,
        label=s.label,
        status=s.status,
        opened_at=s.opened_at,
        closed_at=s.closed_at,
        created_at=s.created_at,
        pre_checkin_count=count,
    )


# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------

@router.get("/{academy_id}/training-templates", response_model=list[TrainingTemplateRead])
async def get_templates(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    verify_academy_access(current_user, str(academy_id))
    return await list_templates(db, academy_id)


@router.post("/{academy_id}/training-templates", response_model=TrainingTemplateRead, status_code=201)
async def post_template(
    academy_id: UUID,
    body: TrainingTemplateCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    verify_academy_access(current_user, str(academy_id))
    return await create_template(db, academy_id, current_user.id, body)


@router.patch("/training-templates/{template_id}", response_model=TrainingTemplateRead)
async def patch_template(
    template_id: UUID,
    body: TrainingTemplateUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    # academy_id verificado dentro do serviço via busca por (id, academy_id)
    academy_id = current_user.academy_id
    if current_user.role == "administrador":
        # admin pode editar qualquer template; busca sem filtro de academia
        from app.models.training_session import TrainingTemplate
        from sqlalchemy import select
        result = await db.execute(select(TrainingTemplate).where(TrainingTemplate.id == template_id))
        t = result.scalar_one_or_none()
        if t:
            academy_id = t.academy_id
    return await update_template(db, template_id, academy_id, body)


@router.delete("/training-templates/{template_id}", status_code=204)
async def del_template(
    template_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    academy_id = current_user.academy_id
    if current_user.role == "administrador":
        from app.models.training_session import TrainingTemplate
        from sqlalchemy import select
        result = await db.execute(select(TrainingTemplate).where(TrainingTemplate.id == template_id))
        t = result.scalar_one_or_none()
        if t:
            academy_id = t.academy_id
    await delete_template(db, template_id, academy_id)


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------

@router.get("/{academy_id}/training-sessions", response_model=list[TrainingSessionRead])
async def get_sessions(
    academy_id: UUID,
    class_date: date | None = Query(None),
    status: str | None = Query(None, pattern="^(upcoming|open|closed)$"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    verify_academy_access(current_user, str(academy_id))
    sessions = await list_sessions(
        db,
        academy_id,
        class_date=str(class_date) if class_date else None,
        status=status,
        limit=limit,
        offset=offset,
    )
    return [await _session_read(db, s) for s in sessions]


@router.get("/{academy_id}/training-sessions/today", response_model=list[TrainingSessionRead])
async def get_sessions_today(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Sessões do dia atual (horário de Brasília). Usado para o link de WhatsApp."""
    from app.core.app_time import today_in_app_tz
    today = today_in_app_tz()
    verify_academy_access(current_user, str(academy_id))
    sessions = await list_sessions(db, academy_id, class_date=str(today), limit=20)
    return [await _session_read(db, s) for s in sessions]


@router.post("/{academy_id}/training-sessions", response_model=TrainingSessionRead, status_code=201)
async def post_session(
    academy_id: UUID,
    body: TrainingSessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    verify_academy_access(current_user, str(academy_id))
    session = await create_session(db, academy_id, current_user, body)
    return await _session_read(db, session)


@router.get("/training-sessions/{session_id}", response_model=TrainingSessionRead)
async def get_session_route(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    session = await get_session(db, session_id)
    verify_academy_access(current_user, str(session.academy_id))
    return await _session_read(db, session)


@router.patch("/training-sessions/{session_id}", response_model=TrainingSessionRead)
async def patch_session(
    session_id: UUID,
    body: TrainingSessionUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    session = await get_session(db, session_id)
    verify_academy_access(current_user, str(session.academy_id))
    updated = await update_session(db, session_id, session.academy_id, body)
    return await _session_read(db, updated)


@router.post("/training-sessions/{session_id}/open", response_model=TrainingSessionRead)
async def open_session_route(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    session = await get_session(db, session_id)
    verify_academy_access(current_user, str(session.academy_id))
    updated = await open_session(db, session_id, session.academy_id)
    return await _session_read(db, updated)


@router.post("/training-sessions/{session_id}/close", response_model=TrainingSessionRead)
async def close_session_route(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    session = await get_session(db, session_id)
    verify_academy_access(current_user, str(session.academy_id))
    updated = await close_session(db, session_id, session.academy_id)
    return await _session_read(db, updated)


@router.delete("/training-sessions/{session_id}", status_code=204)
async def delete_session_route(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    session = await get_session(db, session_id)
    verify_academy_access(current_user, str(session.academy_id))
    await delete_session(db, session_id, session.academy_id)


# ---------------------------------------------------------------------------
# Pre-checkin endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/training-sessions/{session_id}/pre-checkin",
    response_model=PreCheckinStatusRead,
)
async def get_pre_checkin_status(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Status do usuário atual + lista de confirmantes para uma sessão."""
    session = await get_session(db, session_id)
    verify_academy_access(current_user, str(session.academy_id))
    return await pre_checkin_service.get_status(db, session_id, current_user.id)


@router.post(
    "/training-sessions/{session_id}/pre-checkin/confirm",
    response_model=PreCheckinRead,
    status_code=201,
)
async def confirm_pre_checkin(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Aluno confirma presença antecipada no treino."""
    return await pre_checkin_service.confirm(db, session_id, current_user)


@router.post(
    "/training-sessions/{session_id}/pre-checkin/cancel",
    response_model=PreCheckinRead,
)
async def cancel_pre_checkin(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Aluno cancela confirmação de presença antecipada."""
    return await pre_checkin_service.cancel(db, session_id, current_user)


# ---------------------------------------------------------------------------
# Resumo pós-treino (furo inteligente)
# ---------------------------------------------------------------------------

@router.get(
    "/training-sessions/{session_id}/summary",
    response_model=TrainingSessionSummaryRead,
)
async def get_training_session_summary(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Furo inteligente: cruza pré-confirmados × presenças reais após o treino."""
    session = await get_session(db, session_id)
    verify_academy_access(current_user, str(session.academy_id))
    return await get_session_summary(db, session_id, session.academy_id)
