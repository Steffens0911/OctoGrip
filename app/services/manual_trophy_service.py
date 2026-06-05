"""Serviço para troféus manuais: templates, campeonatos e concessões."""

import logging
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError
from app.models.manual_trophy import AcademyChampionshipEvent, AcademyTrophyAward, AcademyTrophyTemplate
from app.services.audit_service import (
    AUDIT_ACTION_CREATE,
    AUDIT_ACTION_DELETE,
    AUDIT_ACTION_UPDATE,
    entity_snapshot_row,
    write_audit_log,
)

logger = logging.getLogger(__name__)

VALID_MEDAL_TYPES = frozenset({"gold", "silver", "bronze", "participation"})
VALID_TROPHY_TYPES = frozenset({"championship", "custom"})

_E_TEMPLATE = "AcademyTrophyTemplate"
_E_EVENT = "AcademyChampionshipEvent"
_E_AWARD = "AcademyTrophyAward"


# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------


async def create_trophy_template(
    db: AsyncSession,
    *,
    academy_id: UUID,
    name: str,
    description: str | None = None,
    icon: str | None = None,
    color: str | None = None,
    trophy_type: str = "custom",
    created_by: UUID | None = None,
    audit_user_id: UUID | None = None,
) -> AcademyTrophyTemplate:
    if trophy_type not in VALID_TROPHY_TYPES:
        raise AppError(f"trophy_type inválido. Use: {', '.join(sorted(VALID_TROPHY_TYPES))}", status_code=400)
    template = AcademyTrophyTemplate(
        academy_id=academy_id,
        name=name.strip(),
        description=description,
        icon=icon,
        color=color,
        trophy_type=trophy_type,
        created_by=created_by,
    )
    db.add(template)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_E_TEMPLATE,
        entity_id=template.id,
        old_data=None,
        new_data=entity_snapshot_row(template),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(template)
    logger.info("create_trophy_template", extra={"template_id": str(template.id), "academy_id": str(academy_id)})
    return template


async def list_trophy_templates(
    db: AsyncSession,
    academy_id: UUID,
    *,
    trophy_type: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[AcademyTrophyTemplate]:
    q = (
        select(AcademyTrophyTemplate)
        .where(
            AcademyTrophyTemplate.academy_id == academy_id,
            AcademyTrophyTemplate.deleted_at.is_(None),
        )
        .order_by(AcademyTrophyTemplate.name)
        .offset(max(0, offset))
        .limit(min(limit, 200))
    )
    if trophy_type:
        q = q.where(AcademyTrophyTemplate.trophy_type == trophy_type)
    return list((await db.execute(q)).scalars().all())


async def get_trophy_template(db: AsyncSession, template_id: UUID) -> AcademyTrophyTemplate | None:
    return (
        await db.execute(select(AcademyTrophyTemplate).where(AcademyTrophyTemplate.id == template_id))
    ).scalar_one_or_none()


async def update_trophy_template(
    db: AsyncSession,
    template_id: UUID,
    updates: dict,
    audit_user_id: UUID | None = None,
) -> AcademyTrophyTemplate:
    template = await get_trophy_template(db, template_id)
    if not template or template.deleted_at is not None:
        raise AppError("Template não encontrado.", status_code=404)
    before = entity_snapshot_row(template)
    for key, value in updates.items():
        if key == "name" and value is not None:
            value = value.strip()
        setattr(template, key, value)
    after = entity_snapshot_row(template)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_E_TEMPLATE,
            entity_id=template.id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(template)
    return template


async def delete_trophy_template(
    db: AsyncSession,
    template_id: UUID,
    audit_user_id: UUID | None = None,
) -> None:
    template = await get_trophy_template(db, template_id)
    if not template or template.deleted_at is not None:
        raise AppError("Template não encontrado.", status_code=404)
    before = entity_snapshot_row(template)
    template.deleted_at = datetime.now(UTC)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_E_TEMPLATE,
        entity_id=template.id,
        old_data=before,
        new_data={"deleted_at": template.deleted_at.isoformat()},
        user_id=audit_user_id,
    )
    await db.commit()


# ---------------------------------------------------------------------------
# Campeonatos
# ---------------------------------------------------------------------------


async def create_championship_event(
    db: AsyncSession,
    *,
    academy_id: UUID,
    name: str,
    location: str | None = None,
    event_date,
    created_by: UUID | None = None,
    audit_user_id: UUID | None = None,
) -> AcademyChampionshipEvent:
    event = AcademyChampionshipEvent(
        academy_id=academy_id,
        name=name.strip(),
        location=location,
        event_date=event_date,
        created_by=created_by,
    )
    db.add(event)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_E_EVENT,
        entity_id=event.id,
        old_data=None,
        new_data=entity_snapshot_row(event),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(event)
    logger.info("create_championship_event", extra={"event_id": str(event.id), "academy_id": str(academy_id)})
    return event


async def list_championship_events(
    db: AsyncSession,
    academy_id: UUID,
    *,
    limit: int = 50,
    offset: int = 0,
) -> list[AcademyChampionshipEvent]:
    return list(
        (
            await db.execute(
                select(AcademyChampionshipEvent)
                .where(
                    AcademyChampionshipEvent.academy_id == academy_id,
                    AcademyChampionshipEvent.deleted_at.is_(None),
                )
                .order_by(AcademyChampionshipEvent.event_date.desc())
                .offset(max(0, offset))
                .limit(min(limit, 200))
            )
        )
        .scalars()
        .all()
    )


async def get_championship_event(db: AsyncSession, event_id: UUID) -> AcademyChampionshipEvent | None:
    return (
        await db.execute(select(AcademyChampionshipEvent).where(AcademyChampionshipEvent.id == event_id))
    ).scalar_one_or_none()


async def update_championship_event(
    db: AsyncSession,
    event_id: UUID,
    updates: dict,
    audit_user_id: UUID | None = None,
) -> AcademyChampionshipEvent:
    event = await get_championship_event(db, event_id)
    if not event or event.deleted_at is not None:
        raise AppError("Campeonato não encontrado.", status_code=404)
    before = entity_snapshot_row(event)
    for key, value in updates.items():
        if key == "name" and value is not None:
            value = value.strip()
        setattr(event, key, value)
    after = entity_snapshot_row(event)
    if after != before:
        await write_audit_log(
            db,
            action=AUDIT_ACTION_UPDATE,
            entity_label=_E_EVENT,
            entity_id=event.id,
            old_data=before,
            new_data=after,
            user_id=audit_user_id,
        )
    await db.commit()
    await db.refresh(event)
    return event


async def delete_championship_event(
    db: AsyncSession,
    event_id: UUID,
    audit_user_id: UUID | None = None,
) -> None:
    event = await get_championship_event(db, event_id)
    if not event or event.deleted_at is not None:
        raise AppError("Campeonato não encontrado.", status_code=404)
    before = entity_snapshot_row(event)
    event.deleted_at = datetime.now(UTC)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_E_EVENT,
        entity_id=event.id,
        old_data=before,
        new_data={"deleted_at": event.deleted_at.isoformat()},
        user_id=audit_user_id,
    )
    await db.commit()


# ---------------------------------------------------------------------------
# Concessões
# ---------------------------------------------------------------------------


async def award_trophy(
    db: AsyncSession,
    *,
    template_id: UUID,
    user_id: UUID,
    awarded_by: UUID | None = None,
    championship_event_id: UUID | None = None,
    medal_type: str | None = None,
    note: str | None = None,
    audit_user_id: UUID | None = None,
) -> AcademyTrophyAward:
    template = await get_trophy_template(db, template_id)
    if not template or template.deleted_at is not None:
        raise AppError("Template de troféu não encontrado.", status_code=404)

    VALID_MEDAL_TYPES_CHAMPIONSHIP = frozenset({"gold", "silver", "bronze", "participation"})
    VALID_MEDAL_TYPES_CUSTOM = frozenset({"gold", "silver", "bronze"})

    if template.trophy_type == "championship":
        if not championship_event_id:
            raise AppError("Troféu de campeonato requer championship_event_id.", status_code=400)
        if not medal_type:
            raise AppError(
                "Troféu de campeonato requer medal_type (gold, silver, bronze, participation).", status_code=400
            )
        if medal_type not in VALID_MEDAL_TYPES_CHAMPIONSHIP:
            raise AppError(
                f"medal_type inválido. Use: {', '.join(sorted(VALID_MEDAL_TYPES_CHAMPIONSHIP))}", status_code=400
            )
        event = await get_championship_event(db, championship_event_id)
        if not event or event.deleted_at is not None:
            raise AppError("Campeonato não encontrado.", status_code=404)
        if event.academy_id != template.academy_id:
            raise AppError("Campeonato não pertence à academia do troféu.", status_code=400)
    else:
        championship_event_id = None
        if medal_type and medal_type not in VALID_MEDAL_TYPES_CUSTOM:
            raise AppError(
                f"medal_type inválido para troféu custom. Use: {', '.join(sorted(VALID_MEDAL_TYPES_CUSTOM))}",
                status_code=400,
            )

    award = AcademyTrophyAward(
        template_id=template_id,
        user_id=user_id,
        awarded_by=awarded_by,
        championship_event_id=championship_event_id,
        medal_type=medal_type,
        note=note,
    )
    db.add(award)
    await db.flush()
    await write_audit_log(
        db,
        action=AUDIT_ACTION_CREATE,
        entity_label=_E_AWARD,
        entity_id=award.id,
        old_data=None,
        new_data=entity_snapshot_row(award),
        user_id=audit_user_id,
    )
    await db.commit()
    await db.refresh(award)
    logger.info(
        "award_trophy",
        extra={"award_id": str(award.id), "template_id": str(template_id), "user_id": str(user_id)},
    )

    # Notificação in-app + push despachado como task Celery (fire-and-forget real)
    try:
        from app.tasks.manual_trophy_tasks import notify_manual_trophy_awarded

        notify_manual_trophy_awarded.delay(str(award.id))
    except Exception:
        logger.exception("award_trophy: erro ao despachar task de notificação", extra={"award_id": str(award.id)})

    return award


async def revoke_award(
    db: AsyncSession,
    award_id: UUID,
    audit_user_id: UUID | None = None,
) -> None:
    award = (await db.execute(select(AcademyTrophyAward).where(AcademyTrophyAward.id == award_id))).scalar_one_or_none()
    if not award:
        raise AppError("Concessão não encontrada.", status_code=404)
    before = entity_snapshot_row(award)
    await db.delete(award)
    await write_audit_log(
        db,
        action=AUDIT_ACTION_DELETE,
        entity_label=_E_AWARD,
        entity_id=award_id,
        old_data=before,
        new_data=None,
        user_id=audit_user_id,
    )
    await db.commit()
    logger.info("revoke_award", extra={"award_id": str(award_id)})


async def list_awards_for_user(db: AsyncSession, user_id: UUID) -> list[AcademyTrophyAward]:
    return list(
        (
            await db.execute(
                select(AcademyTrophyAward)
                .where(AcademyTrophyAward.user_id == user_id)
                .order_by(AcademyTrophyAward.awarded_at.desc())
            )
        )
        .scalars()
        .all()
    )


async def list_awards_for_template(
    db: AsyncSession,
    template_id: UUID,
    *,
    limit: int = 50,
    offset: int = 0,
) -> list[AcademyTrophyAward]:
    return list(
        (
            await db.execute(
                select(AcademyTrophyAward)
                .where(AcademyTrophyAward.template_id == template_id)
                .order_by(AcademyTrophyAward.awarded_at.desc())
                .offset(max(0, offset))
                .limit(min(limit, 200))
            )
        )
        .scalars()
        .all()
    )


def _award_to_dict(award: AcademyTrophyAward) -> dict:
    """Converte award para dict compatível com TrophyAwardRead."""
    template = award.template
    event = award.championship_event
    return {
        "id": award.id,
        "template_id": award.template_id,
        "template_name": template.name if template else "",
        "template_icon": template.icon if template else None,
        "template_color": template.color if template else None,
        "trophy_type": template.trophy_type if template else "custom",
        "user_id": award.user_id,
        "awarded_by": award.awarded_by,
        "awarded_at": award.awarded_at,
        "championship_event_id": award.championship_event_id,
        "championship_event_name": event.name if event else None,
        "championship_event_date": event.event_date if event else None,
        "medal_type": award.medal_type,
        "note": award.note,
    }
