"""Persistência de tokens FCM por utilizador."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User, UserDeviceToken


async def upsert_device_token(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    fcm_token: str,
    platform: str,
) -> None:
    """Associa o token ao utilizador; se o token existir para outro utilizador, reatribui."""
    token = fcm_token.strip()
    if not token:
        return

    stmt = (
        pg_insert(UserDeviceToken)
        .values(
            user_id=user_id,
            fcm_token=token,
            platform=platform[:16],
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
        .on_conflict_do_update(
            index_elements=[UserDeviceToken.fcm_token],
            set_={
                "user_id": user_id,
                "platform": platform[:16],
                "updated_at": datetime.now(UTC),
            },
        )
    )
    await db.execute(stmt)
    await db.commit()


async def delete_device_token(db: AsyncSession, *, fcm_token: str) -> None:
    await db.execute(delete(UserDeviceToken).where(UserDeviceToken.fcm_token == fcm_token.strip()))
    await db.commit()


async def list_fcm_tokens_for_academy(db: AsyncSession, *, academy_id: uuid.UUID) -> list[str]:
    """Tokens distintos de utilizadores com academy_id igual (inclui alunos, professores, etc.)."""
    stmt = (
        select(UserDeviceToken.fcm_token)
        .join(User, User.id == UserDeviceToken.user_id)
        .where(User.academy_id == academy_id)
        .distinct()
    )
    result = await db.execute(stmt)
    return [row[0] for row in result.fetchall()]
