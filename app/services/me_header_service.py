"""Serviço agregado para dados do header da home do aluno."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.leveling import threshold_for_level
from app.models import Academy, User
from app.schemas.me_header import MeHeaderAcademyRead, MeHeaderStatsRead


async def get_me_header_stats(db: AsyncSession, *, current_user: User) -> MeHeaderStatsRead:
    """Retorna snapshot leve para renderização do header/home.

    Usa campos persistidos (`reward_level`, `reward_level_points`) para evitar
    recomputações custosas em cada carregamento.
    """
    user = (
        await db.execute(
            select(User).where(User.id == current_user.id)
        )
    ).scalar_one_or_none()
    if user is None:
        user = current_user

    level = max(1, int(user.reward_level or 1))
    level_points = max(0, int(user.reward_level_points or 0))
    next_threshold = threshold_for_level(level)

    academy_payload: MeHeaderAcademyRead | None = None
    if user.academy_id:
        academy = (
            await db.execute(
                select(Academy).where(Academy.id == user.academy_id)
            )
        ).scalar_one_or_none()
        if academy is not None:
            academy_payload = MeHeaderAcademyRead(
                id=academy.id,
                name=academy.name,
                logo_url=academy.logo_url,
                schedule_image_url=academy.schedule_image_url,
                show_trophies=academy.show_trophies,
                show_partners=academy.show_partners,
                show_schedule=academy.show_schedule,
                show_global_supporters=academy.show_global_supporters,
                login_notice_title=academy.login_notice_title,
                login_notice_body=academy.login_notice_body,
                login_notice_url=academy.login_notice_url,
                login_notice_active=academy.login_notice_active,
            )

    return MeHeaderStatsRead(
        user_id=user.id,
        reward_level=level,
        reward_level_points=level_points,
        next_level_threshold=next_threshold,
        academy=academy_payload,
    )
