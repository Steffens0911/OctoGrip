"""Service para pré-checkin (confirmação antecipada de presença em treinos)."""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_time import get_app_tz, utc_now
from app.core.exceptions import ForbiddenError, NotFoundError
from app.models import User
from app.models.training_pre_checkin import TrainingPreCheckin
from app.models.training_session import TrainingSession
from app.schemas.training_session import ConfirmantRead, PreCheckinStatusRead


class PreCheckinWindowClosedError(ForbiddenError):
    def __init__(self) -> None:
        super().__init__(
            "O prazo para confirmação encerrou (30 min antes do treino)."
        )


class PreCheckinSessionNotOpen(ForbiddenError):
    def __init__(self) -> None:
        super().__init__("Este treino não está mais aceitando confirmações.")


def _cutoff_utc(class_date: date, start_time: str) -> datetime:
    """Retorna o instante UTC em que a janela de confirmação fecha (30 min antes do treino)."""
    hour, minute = map(int, start_time.split(":"))
    tz = get_app_tz()
    local_start = datetime.combine(class_date, time(hour, minute), tzinfo=tz)
    return (local_start - timedelta(minutes=30)).astimezone(UTC)


def _check_window(session: TrainingSession) -> None:
    """Lança erro se a janela de confirmação já fechou."""
    if session.status != "upcoming":
        raise PreCheckinSessionNotOpen()
    cutoff = _cutoff_utc(session.class_date, session.start_time)
    if utc_now() >= cutoff:
        raise PreCheckinWindowClosedError()


async def confirm(
    db: AsyncSession,
    session_id: UUID,
    user: User,
) -> TrainingPreCheckin:
    """Aluno confirma presença antecipada."""
    result = await db.execute(
        select(TrainingSession).where(TrainingSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise NotFoundError("Treino não encontrado.")
    if str(session.academy_id) != str(user.academy_id):
        raise ForbiddenError("Você não pertence a esta academia.")

    _check_window(session)

    # Busca registro existente (pode ser um cancel anterior)
    existing_result = await db.execute(
        select(TrainingPreCheckin).where(
            TrainingPreCheckin.training_session_id == session_id,
            TrainingPreCheckin.user_id == user.id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    now = utc_now()
    if existing:
        existing.status = "confirmed"
        existing.confirmed_at = now
        existing.cancelled_at = None
        await db.commit()
        await db.refresh(existing)
        return existing

    checkin = TrainingPreCheckin(
        training_session_id=session_id,
        user_id=user.id,
        academy_id=session.academy_id,
        status="confirmed",
        confirmed_at=now,
    )
    db.add(checkin)
    await db.commit()
    await db.refresh(checkin)
    return checkin


async def cancel(
    db: AsyncSession,
    session_id: UUID,
    user: User,
) -> TrainingPreCheckin:
    """Aluno cancela confirmação."""
    result = await db.execute(
        select(TrainingPreCheckin).where(
            TrainingPreCheckin.training_session_id == session_id,
            TrainingPreCheckin.user_id == user.id,
            TrainingPreCheckin.status == "confirmed",
        )
    )
    checkin = result.scalar_one_or_none()
    if not checkin:
        raise NotFoundError("Confirmação não encontrada.")

    # Verifica janela antes de cancelar
    session_result = await db.execute(
        select(TrainingSession).where(TrainingSession.id == session_id)
    )
    session = session_result.scalar_one_or_none()
    if session:
        _check_window(session)

    checkin.status = "cancelled"
    checkin.cancelled_at = utc_now()
    await db.commit()
    await db.refresh(checkin)
    return checkin


async def get_status(
    db: AsyncSession,
    session_id: UUID,
    user_id: UUID,
) -> PreCheckinStatusRead:
    """Status do usuário atual + lista de confirmantes para uma sessão."""
    # Registro do usuário
    user_result = await db.execute(
        select(TrainingPreCheckin).where(
            TrainingPreCheckin.training_session_id == session_id,
            TrainingPreCheckin.user_id == user_id,
        )
    )
    user_checkin = user_result.scalar_one_or_none()

    # Lista de confirmantes (lazy="selectin" carrega user automaticamente)
    confirmants_result = await db.execute(
        select(TrainingPreCheckin).where(
            TrainingPreCheckin.training_session_id == session_id,
            TrainingPreCheckin.status == "confirmed",
        ).order_by(TrainingPreCheckin.confirmed_at)
    )
    confirmants = list(confirmants_result.scalars().all())

    confirmant_reads = [
        ConfirmantRead(
            user_id=c.user_id,
            name=c.user.name,
            avatar_url=c.user.avatar_url if hasattr(c.user, "avatar_url") else None,
        )
        for c in confirmants
    ]

    return PreCheckinStatusRead(
        pre_checkin_id=user_checkin.id if user_checkin else None,
        status=user_checkin.status if user_checkin else None,
        confirmed_at=user_checkin.confirmed_at if user_checkin else None,
        cancelled_at=user_checkin.cancelled_at if user_checkin else None,
        confirmants=confirmant_reads,
        total_confirmed=len(confirmant_reads),
    )


async def count_confirmed(db: AsyncSession, session_id: UUID) -> int:
    """Contagem de confirmados para uma sessão (para o professor)."""
    result = await db.execute(
        select(func.count()).select_from(TrainingPreCheckin).where(
            TrainingPreCheckin.training_session_id == session_id,
            TrainingPreCheckin.status == "confirmed",
        )
    )
    return result.scalar_one() or 0
