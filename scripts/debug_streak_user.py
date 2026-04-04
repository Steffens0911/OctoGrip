"""Diagnóstico: streak e UserRead para um user_id. Uso: docker compose exec api python /app/scripts/debug_streak_user.py"""
import asyncio
import sys
from uuid import UUID

from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models import User
from app.services.login_streak_service import (
    compute_login_streak_days,
    user_read_with_login_streak,
)

USER_ID = UUID("f63ba10a-186c-4d84-8809-51e4f6ce8ea5")


async def main() -> None:
    async with AsyncSessionLocal() as db:
        streak = await compute_login_streak_days(db, USER_ID)
        print("compute_login_streak_days:", streak)
        r = await db.execute(select(User).where(User.id == USER_ID))
        u = r.scalar_one()
        ur = await user_read_with_login_streak(db, u)
        print("model_dump_json:", ur.model_dump_json())


if __name__ == "__main__":
    asyncio.run(main())
    sys.exit(0)
