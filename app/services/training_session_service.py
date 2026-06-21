"""Serviços para treinos lançados pelo professor e templates (favoritos)."""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenError, NotFoundError
from app.models import Academy, User
from app.models.attendance_session import AttendanceSession
from app.models.attendance_record import AttendanceRecord
from app.models.training_pre_checkin import TrainingPreCheckin
from app.models.training_session import TrainingSession, TrainingTemplate
from app.schemas.training_session import (
    PersonSummaryRead,
    TrainingSessionCreate,
    TrainingSessionSummaryRead,
    TrainingSessionUpdate,
    TrainingTemplateCreate,
    TrainingTemplateUpdate,
)


class TrainingSessionNotFoundError(NotFoundError):
    def __init__(self) -> None:
        super().__init__("Treino não encontrado.")


class TrainingTemplateNotFoundError(NotFoundError):
    def __init__(self) -> None:
        super().__init__("Favorito não encontrado.")


class PreCheckinNotEnabledError(ForbiddenError):
    def __init__(self) -> None:
        super().__init__("Pré-checkin não está habilitado para esta academia.")


# ---------------------------------------------------------------------------
# Templates (favoritos)
# ---------------------------------------------------------------------------

async def list_templates(db: AsyncSession, academy_id: UUID) -> list[TrainingTemplate]:
    result = await db.execute(
        select(TrainingTemplate)
        .where(TrainingTemplate.academy_id == academy_id)
        .order_by(TrainingTemplate.sort_order, TrainingTemplate.created_at)
    )
    return list(result.scalars().all())


async def create_template(
    db: AsyncSession,
    academy_id: UUID,
    user_id: UUID,
    body: TrainingTemplateCreate,
) -> TrainingTemplate:
    template = TrainingTemplate(
        academy_id=academy_id,
        created_by_user_id=user_id,
        label=body.label,
        start_time=body.start_time,
        tolerance_minutes=body.tolerance_minutes,
        sort_order=body.sort_order,
    )
    db.add(template)
    await db.commit()
    await db.refresh(template)
    return template


async def update_template(
    db: AsyncSession,
    template_id: UUID,
    academy_id: UUID,
    body: TrainingTemplateUpdate,
) -> TrainingTemplate:
    result = await db.execute(
        select(TrainingTemplate).where(
            TrainingTemplate.id == template_id,
            TrainingTemplate.academy_id == academy_id,
        )
    )
    template = result.scalar_one_or_none()
    if not template:
        raise TrainingTemplateNotFoundError()
    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(template, key, value)
    await db.commit()
    await db.refresh(template)
    return template


async def delete_template(db: AsyncSession, template_id: UUID, academy_id: UUID) -> None:
    result = await db.execute(
        select(TrainingTemplate).where(
            TrainingTemplate.id == template_id,
            TrainingTemplate.academy_id == academy_id,
        )
    )
    template = result.scalar_one_or_none()
    if not template:
        raise TrainingTemplateNotFoundError()
    await db.delete(template)
    await db.commit()


# ---------------------------------------------------------------------------
# Sessions (treinos lançados)
# ---------------------------------------------------------------------------

async def _get_academy(db: AsyncSession, academy_id: UUID) -> Academy:
    result = await db.execute(select(Academy).where(Academy.id == academy_id))
    academy = result.scalar_one_or_none()
    if not academy:
        raise NotFoundError("Academia não encontrada.")
    return academy


async def list_sessions(
    db: AsyncSession,
    academy_id: UUID,
    class_date: str | None = None,
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[TrainingSession]:
    q = select(TrainingSession).where(TrainingSession.academy_id == academy_id)
    if class_date:
        q = q.where(TrainingSession.class_date == class_date)
    if status:
        q = q.where(TrainingSession.status == status)
    q = q.order_by(TrainingSession.class_date, TrainingSession.start_time).limit(limit).offset(offset)
    result = await db.execute(q)
    return list(result.scalars().all())


async def get_session(db: AsyncSession, session_id: UUID) -> TrainingSession:
    result = await db.execute(
        select(TrainingSession).where(TrainingSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise TrainingSessionNotFoundError()
    return session


async def create_session(
    db: AsyncSession,
    academy_id: UUID,
    user: User,
    body: TrainingSessionCreate,
) -> TrainingSession:
    academy = await _get_academy(db, academy_id)
    if not academy.pre_checkin_enabled:
        raise PreCheckinNotEnabledError()

    session = TrainingSession(
        academy_id=academy_id,
        created_by_user_id=user.id,
        template_id=body.template_id,
        class_date=body.class_date,
        start_time=body.start_time,
        tolerance_minutes=body.tolerance_minutes,
        label=body.label,
        status="upcoming",
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


async def update_session(
    db: AsyncSession,
    session_id: UUID,
    academy_id: UUID,
    body: TrainingSessionUpdate,
) -> TrainingSession:
    session = await get_session(db, session_id)
    if str(session.academy_id) != str(academy_id):
        raise TrainingSessionNotFoundError()
    if session.status != "upcoming":
        raise ForbiddenError("Só é possível editar treinos que ainda não foram abertos.")
    updates = body.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(session, key, value)
    await db.commit()
    await db.refresh(session)
    return session


async def open_session(db: AsyncSession, session_id: UUID, academy_id: UUID) -> TrainingSession:
    session = await get_session(db, session_id)
    if str(session.academy_id) != str(academy_id):
        raise TrainingSessionNotFoundError()
    if session.status != "upcoming":
        raise ForbiddenError("O treino já foi aberto ou encerrado.")
    session.status = "open"
    session.opened_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(session)
    return session


async def close_session(db: AsyncSession, session_id: UUID, academy_id: UUID) -> TrainingSession:
    session = await get_session(db, session_id)
    if str(session.academy_id) != str(academy_id):
        raise TrainingSessionNotFoundError()
    if session.status == "closed":
        raise ForbiddenError("O treino já está encerrado.")
    session.status = "closed"
    session.closed_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(session)
    return session


async def delete_session(db: AsyncSession, session_id: UUID, academy_id: UUID) -> None:
    session = await get_session(db, session_id)
    if str(session.academy_id) != str(academy_id):
        raise TrainingSessionNotFoundError()
    if session.status == "open":
        raise ForbiddenError("Encerre a chamada antes de excluir o treino.")
    await db.delete(session)
    await db.commit()


async def get_session_summary(
    db: AsyncSession,
    session_id: UUID,
    academy_id: UUID,
) -> TrainingSessionSummaryRead:
    """Cruza pré-confirmados × presenças reais para o furo inteligente."""
    session = await get_session(db, session_id)
    if str(session.academy_id) != str(academy_id):
        raise TrainingSessionNotFoundError()

    # IDs de quem pré-confirmou (status = confirmed)
    pre_rows = (
        await db.execute(
            select(TrainingPreCheckin.user_id).where(
                TrainingPreCheckin.training_session_id == session_id,
                TrainingPreCheckin.status == "confirmed",
            )
        )
    ).scalars().all()
    pre_confirmed_ids: set[UUID] = set(pre_rows)

    # IDs de quem bateu presença via qualquer chamada vinculada a este treino
    attended_rows = (
        await db.execute(
            select(AttendanceRecord.user_id)
            .join(AttendanceSession, AttendanceRecord.session_id == AttendanceSession.id)
            .where(AttendanceSession.training_session_id == session_id)
            .distinct()
        )
    ).scalars().all()
    attended_ids: set[UUID] = set(attended_rows)

    # Todos os user_ids envolvidos
    all_ids = pre_confirmed_ids | attended_ids
    user_rows = (
        await db.execute(
            select(User.id, User.name, User.avatar_url).where(User.id.in_(all_ids))
        )
    ).all() if all_ids else []
    user_map: dict[UUID, tuple[str | None, str | None]] = {
        row[0]: (row[1], row[2]) for row in user_rows
    }

    def _person(uid: UUID) -> PersonSummaryRead:
        name, avatar_url = user_map.get(uid, (None, None))
        return PersonSummaryRead(user_id=uid, name=name, avatar_url=avatar_url)

    furos_ids = pre_confirmed_ids - attended_ids
    surpresas_ids = attended_ids - pre_confirmed_ids
    intersection_ids = pre_confirmed_ids & attended_ids

    return TrainingSessionSummaryRead(
        training_session_id=session_id,
        label=session.label,
        class_date=session.class_date,
        start_time=session.start_time,
        total_pre_confirmed=len(pre_confirmed_ids),
        total_attended=len(attended_ids),
        confirmed_and_attended=[_person(uid) for uid in sorted(intersection_ids, key=str)],
        furos=[_person(uid) for uid in sorted(furos_ids, key=str)],
        surpresas=[_person(uid) for uid in sorted(surpresas_ids, key=str)],
    )
