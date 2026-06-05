"""Detecta troféus/medalhas recém-conquistados após confirmação de execução e envia push."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import Trophy, User
from app.models.user_trophy_earned import UserTrophyEarned
from app.services.fcm_service import fetch_fcm_access_token, send_fcm_data_message
from app.services.push_token_service import list_fcm_tokens_for_academy, list_fcm_tokens_for_user
from app.services.trophy_service import (
    _compute_counts_from_executions,
    _executions_in_period_from_list,
    _load_confirmed_executions_for_user,
    _tier_from_counts,
)

logger = logging.getLogger(__name__)

_TIER_LABEL = {"bronze": "Bronze 🥉", "silver": "Prata 🥈", "gold": "Ouro 🥇"}
_KIND_LABEL = {"medal": "Medalha", "trophy": "Troféu"}
_TIER_ORDER = {None: 0, "bronze": 1, "silver": 2, "gold": 3}


async def _get_previous_tier(db: AsyncSession, user_id: UUID, trophy_id: UUID) -> str | None:
    return (
        await db.execute(
            select(UserTrophyEarned.tier).where(
                UserTrophyEarned.user_id == user_id,
                UserTrophyEarned.trophy_id == trophy_id,
            )
        )
    ).scalar_one_or_none()


async def _upsert_earned(db: AsyncSession, user_id: UUID, trophy_id: UUID, tier: str) -> None:
    now = datetime.now(UTC)
    stmt = (
        pg_insert(UserTrophyEarned)
        .values(user_id=user_id, trophy_id=trophy_id, tier=tier, earned_at=now, updated_at=now)
        .on_conflict_do_update(
            constraint="user_trophy_earned_unique",
            set_={"tier": tier, "updated_at": now},
        )
    )
    await db.execute(stmt)
    await db.commit()


async def _broadcast(
    tokens: list[str],
    *,
    title: str,
    body: str,
    data: dict[str, str],
    access_token: str,
) -> None:
    for token in tokens:
        _, drop = await send_fcm_data_message(
            project_id=settings.FIREBASE_PROJECT_ID,
            service_account_path=settings.FIREBASE_SERVICE_ACCOUNT_PATH,
            device_token=token,
            title=title,
            body=body,
            access_token=access_token,
            data=data,
        )
        if drop:
            logger.info("trophy_notification: token inválido descartado", extra={"token_prefix": token[:12]})


async def _send_trophy_pushes(
    db: AsyncSession,
    user: User,
    academy_id: UUID,
    trophy: Trophy,
    tier: str,
    upgraded: bool,
) -> None:
    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        return

    try:
        access_token = await fetch_fcm_access_token(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    except Exception:
        logger.exception("trophy_notification: falha ao obter access token FCM")
        return

    kind_label = _KIND_LABEL.get(getattr(trophy, "award_kind", "trophy"), "Troféu")
    tier_label = _TIER_LABEL.get(tier, tier.capitalize())
    trophy_data = {"type": "trophy_earned", "trophy_id": str(trophy.id), "tier": tier}

    # Push pessoal para o aluno que conquistou
    personal_tokens = await list_fcm_tokens_for_user(db, user_id=user.id)
    if personal_tokens:
        personal_title = (
            f"{kind_label} evoluído! {tier_label}" if upgraded else f"{kind_label} conquistado! {tier_label}"
        )
        await _broadcast(
            personal_tokens,
            title=personal_title,
            body=trophy.name,
            data=trophy_data,
            access_token=access_token,
        )

    # Push social para toda a academia (inclui professores e gerentes)
    user_name = (user.name or "Um aluno").strip()
    academy_tokens = await list_fcm_tokens_for_academy(db, academy_id=academy_id)
    # Exclui tokens que já receberam o push pessoal para não duplicar no próprio dispositivo
    personal_set = set(personal_tokens)
    social_tokens = [t for t in academy_tokens if t not in personal_set]
    if social_tokens:
        social_title = f"{user_name} conquistou {tier_label}"
        social_body = f"{kind_label}: {trophy.name}"
        await _broadcast(
            social_tokens,
            title=social_title,
            body=social_body,
            data=trophy_data,
            access_token=access_token,
        )


async def check_and_notify_trophy_earned(
    db: AsyncSession,
    user_id: UUID,
    technique_id: UUID | None,
) -> None:
    """
    Chamado após confirm_execution. Verifica se o usuário acabou de conquistar (ou subir de tier)
    algum troféu/medalha da academia cuja técnica coincida com a execução confirmada.
    Registra na tabela user_trophy_earned e envia push para o aluno e para toda a academia.
    """
    if technique_id is None:
        return

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user or not user.academy_id:
        return

    trophies: list[Trophy] = (
        (
            await db.execute(
                select(Trophy).where(
                    Trophy.academy_id == user.academy_id,
                    Trophy.technique_id == technique_id,
                    Trophy.deleted_at.is_(None),
                )
            )
        )
        .scalars()
        .all()
    )

    if not trophies:
        return

    all_executions = await _load_confirmed_executions_for_user(db, user_id)

    for trophy in trophies:
        in_period = _executions_in_period_from_list(all_executions, trophy)
        counts = _compute_counts_from_executions(in_period, getattr(trophy, "max_count_per_opponent", None))
        current_tier = _tier_from_counts(counts, trophy.target_count)

        if current_tier is None:
            continue

        previous_tier = await _get_previous_tier(db, user_id, trophy.id)
        if _TIER_ORDER[current_tier] <= _TIER_ORDER[previous_tier]:
            continue

        upgraded = previous_tier is not None
        await _upsert_earned(db, user_id, trophy.id, current_tier)

        # Post automático no feed OctoPhotos (opt-out: criado imediatamente, aluno pode deletar).
        try:
            from app.services.academy_service import get_academy
            from app.services.photos_service import create_system_post, invalidate_feed_cache

            academy = await get_academy(db, user.academy_id)
            if academy and getattr(academy, "octophotos_enabled", False):
                _tier_labels = {"bronze": "Bronze 🥉", "silver": "Prata 🥈", "gold": "Ouro 🥇"}
                _kind_labels = {"medal": "Medalha", "trophy": "Troféu"}
                kind_label = _kind_labels.get(getattr(trophy, "award_kind", "trophy"), "Troféu")
                tier_label = _tier_labels.get(current_tier, current_tier.capitalize())
                caption = f"{kind_label} {tier_label}: {trophy.name}"
                await create_system_post(
                    db,
                    academy_id=user.academy_id,
                    author_id=user_id,
                    system_post_type="trophy",
                    system_post_ref_id=trophy.id,
                    caption=caption,
                )
                await db.commit()
                await invalidate_feed_cache(user.academy_id)
        except Exception:
            logger.exception("trophy_notification: erro ao criar post automático OctoPhotos")

        logger.info(
            "trophy_notification: conquista detectada",
            extra={
                "user_id": str(user_id),
                "trophy_id": str(trophy.id),
                "tier": current_tier,
                "upgraded": upgraded,
            },
        )

        # Cria notificações in-app: pessoal + social para a academia (fire-and-forget).
        try:
            from app.services.notification_service import (
                create_notification,
                create_notifications_for_academy_students,
            )

            kind_label = _KIND_LABEL.get(getattr(trophy, "award_kind", "trophy"), "Troféu")
            tier_label = _TIER_LABEL.get(current_tier, current_tier.capitalize())
            personal_title = (
                f"{kind_label} evoluído! {tier_label}" if upgraded else f"{kind_label} conquistado! {tier_label}"
            )
            trophy_data = {"trophy_id": str(trophy.id), "tier": current_tier}
            await create_notification(
                db,
                user_id=user_id,
                type="trophy_earned",
                title=personal_title,
                body=trophy.name,
                data=trophy_data,
            )
            user_name = (user.name or "Um aluno").strip()
            await create_notifications_for_academy_students(
                db,
                academy_id=user.academy_id,
                type="trophy_social",
                title=f"{user_name} conquistou {tier_label}",
                body=f"{kind_label}: {trophy.name}",
                data=trophy_data,
                exclude_user_id=user_id,
            )
        except Exception:
            logger.exception("trophy_notification: erro ao criar notificações in-app")

        await _send_trophy_pushes(db, user, user.academy_id, trophy, current_tier, upgraded)
