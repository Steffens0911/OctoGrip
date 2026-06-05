"""Rotas para troféus manuais: templates, campeonatos e concessões."""

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import AppError, ForbiddenError
from app.core.role_deps import require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.manual_trophy import (
    ChampionshipEventCreate,
    ChampionshipEventRead,
    ChampionshipEventUpdate,
    TrophyAwardCreate,
    TrophyAwardRead,
    TrophyTemplateCreate,
    TrophyTemplateRead,
    TrophyTemplateUpdate,
    UserTrophyAwardsResponse,
)
from app.services.manual_trophy_service import (
    _award_to_dict,
    award_trophy,
    create_championship_event,
    create_trophy_template,
    delete_championship_event,
    delete_trophy_template,
    get_championship_event,
    get_trophy_template,
    list_awards_for_template,
    list_awards_for_user,
    list_championship_events,
    list_trophy_templates,
    revoke_award,
    update_championship_event,
    update_trophy_template,
)
from app.services.user_service import get_user_or_raise

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------


@router.post("/templates", response_model=TrophyTemplateRead, status_code=201)
async def template_create(
    body: TrophyTemplateCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria um template de troféu/medalha para a academia."""
    verify_academy_access(current_user, str(body.academy_id))
    template = await create_trophy_template(
        db,
        academy_id=body.academy_id,
        name=body.name,
        description=body.description,
        icon=body.icon,
        color=body.color,
        trophy_type=body.trophy_type,
        created_by=current_user.id,
        audit_user_id=current_user.id,
    )
    return TrophyTemplateRead.model_validate(template)


@router.get("/templates", response_model=list[TrophyTemplateRead])
async def template_list(
    academy_id: UUID = Query(...),
    trophy_type: str | None = Query(default=None, description="championship | custom"),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista templates de troféus da academia."""
    verify_academy_access(current_user, str(academy_id))
    templates = await list_trophy_templates(db, academy_id, trophy_type=trophy_type, limit=limit, offset=offset)
    return [TrophyTemplateRead.model_validate(t) for t in templates]


@router.patch("/templates/{template_id}", response_model=TrophyTemplateRead)
async def template_update(
    template_id: UUID,
    body: TrophyTemplateUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza nome, descrição, ícone ou cor de um template."""
    template = await get_trophy_template(db, template_id)
    if not template or template.deleted_at is not None:
        raise AppError("Template não encontrado.", status_code=404)
    verify_academy_access(current_user, str(template.academy_id))
    updated = await update_trophy_template(
        db, template_id, body.model_dump(exclude_unset=True), audit_user_id=current_user.id
    )
    return TrophyTemplateRead.model_validate(updated)


@router.delete("/templates/{template_id}", status_code=204)
async def template_delete(
    template_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove template (soft delete)."""
    template = await get_trophy_template(db, template_id)
    if not template or template.deleted_at is not None:
        raise AppError("Template não encontrado.", status_code=404)
    verify_academy_access(current_user, str(template.academy_id))
    await delete_trophy_template(db, template_id, audit_user_id=current_user.id)


# ---------------------------------------------------------------------------
# Campeonatos
# ---------------------------------------------------------------------------


@router.post("/championships", response_model=ChampionshipEventRead, status_code=201)
async def championship_create(
    body: ChampionshipEventCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria um evento de campeonato."""
    verify_academy_access(current_user, str(body.academy_id))
    event = await create_championship_event(
        db,
        academy_id=body.academy_id,
        name=body.name,
        location=body.location,
        event_date=body.event_date,
        created_by=current_user.id,
        audit_user_id=current_user.id,
    )
    return ChampionshipEventRead.model_validate(event)


@router.get("/championships", response_model=list[ChampionshipEventRead])
async def championship_list(
    academy_id: UUID = Query(...),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista campeonatos da academia."""
    verify_academy_access(current_user, str(academy_id))
    events = await list_championship_events(db, academy_id, limit=limit, offset=offset)
    return [ChampionshipEventRead.model_validate(e) for e in events]


@router.patch("/championships/{event_id}", response_model=ChampionshipEventRead)
async def championship_update(
    event_id: UUID,
    body: ChampionshipEventUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    event = await get_championship_event(db, event_id)
    if not event or event.deleted_at is not None:
        raise AppError("Campeonato não encontrado.", status_code=404)
    verify_academy_access(current_user, str(event.academy_id))
    updated = await update_championship_event(
        db, event_id, body.model_dump(exclude_unset=True), audit_user_id=current_user.id
    )
    return ChampionshipEventRead.model_validate(updated)


@router.delete("/championships/{event_id}", status_code=204)
async def championship_delete(
    event_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    event = await get_championship_event(db, event_id)
    if not event or event.deleted_at is not None:
        raise AppError("Campeonato não encontrado.", status_code=404)
    verify_academy_access(current_user, str(event.academy_id))
    await delete_championship_event(db, event_id, audit_user_id=current_user.id)


# ---------------------------------------------------------------------------
# Concessões
# ---------------------------------------------------------------------------


@router.post("/awards", response_model=TrophyAwardRead, status_code=201)
async def award_create(
    body: TrophyAwardCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Concede troféu/medalha a um aluno."""
    template = await get_trophy_template(db, body.template_id)
    if not template or template.deleted_at is not None:
        raise AppError("Template não encontrado.", status_code=404)
    verify_academy_access(current_user, str(template.academy_id))

    # Garante que o aluno pertence à academia
    target_user = await get_user_or_raise(db, body.user_id)
    if current_user.role != "administrador":
        if str(target_user.academy_id) != str(template.academy_id):
            raise ForbiddenError("O aluno não pertence à academia deste troféu.")

    award = await award_trophy(
        db,
        template_id=body.template_id,
        user_id=body.user_id,
        awarded_by=current_user.id,
        championship_event_id=body.championship_event_id,
        medal_type=body.medal_type,
        note=body.note,
        audit_user_id=current_user.id,
    )
    return TrophyAwardRead(**_award_to_dict(award))


@router.delete("/awards/{award_id}", status_code=204)
async def award_revoke(
    award_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove concessão de troféu."""
    from sqlalchemy import select

    from app.models.manual_trophy import AcademyTrophyAward

    award = (await db.execute(select(AcademyTrophyAward).where(AcademyTrophyAward.id == award_id))).scalar_one_or_none()
    if not award:
        raise AppError("Concessão não encontrada.", status_code=404)
    template = await get_trophy_template(db, award.template_id)
    if template:
        verify_academy_access(current_user, str(template.academy_id))
    await revoke_award(db, award_id, audit_user_id=current_user.id)


@router.get("/awards/template/{template_id}", response_model=list[TrophyAwardRead])
async def awards_by_template(
    template_id: UUID,
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista todas as concessões de um template específico."""
    template = await get_trophy_template(db, template_id)
    if not template or template.deleted_at is not None:
        raise AppError("Template não encontrado.", status_code=404)
    verify_academy_access(current_user, str(template.academy_id))
    awards = await list_awards_for_template(db, template_id, limit=limit, offset=offset)
    return [TrophyAwardRead(**_award_to_dict(a)) for a in awards]


@router.get("/awards/user/{user_id}", response_model=UserTrophyAwardsResponse)
async def awards_by_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retorna todos os troféus manuais de um aluno, agrupados por tipo."""
    target_user = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador":
        verify_academy_access(current_user, str(target_user.academy_id) if target_user.academy_id else None)

    awards = await list_awards_for_user(db, user_id)
    championship_awards = [
        TrophyAwardRead(**_award_to_dict(a)) for a in awards if a.template and a.template.trophy_type == "championship"
    ]
    custom_awards = [
        TrophyAwardRead(**_award_to_dict(a)) for a in awards if a.template and a.template.trophy_type == "custom"
    ]

    return UserTrophyAwardsResponse(
        user_id=user_id,
        championship_awards=championship_awards,
        custom_awards=custom_awards,
    )
