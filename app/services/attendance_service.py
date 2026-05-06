from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Literal, NamedTuple
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.cache import app_cache
from app.core.list_pagination import clamp_list_limit
from app.core.exceptions import (
    AppError,
    AttendanceRecordNotFoundError,
    AttendanceSessionClosedError,
    AttendanceSessionNotFoundError,
    ForbiddenError,
    NotFoundError,
    UserNotFoundError,
)
from app.core.role_deps import verify_academy_access
from app.models import Academy, AttendanceRecord, AttendanceSession, User


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


_ATTENDANCE_RANKING_TTL_SEC = 300
_ATTENDANCE_RANKING_PREFIX = "attendance_ranking:"
_STATS_ME_TTL_SEC = 120
_STATS_ME_PREFIX = "stats_me:"
_STATS_DETAIL_TTL_SEC = 120
_STATS_DETAIL_PREFIX = "stats_detail:"


async def invalidate_attendance_ranking_cache(academy_id: UUID | None) -> None:
    """Invalida cache do ranking de presença para a academia."""
    if academy_id is None:
        return
    await app_cache.bump_prefix_version(f"{_ATTENDANCE_RANKING_PREFIX}{academy_id}:")


async def invalidate_attendance_stats_cache(
    academy_id: UUID | None,
    user_id: UUID | None = None,
) -> None:
    """Invalida cache de stats de presença para academia e/ou usuário."""
    if academy_id is not None:
        await app_cache.bump_prefix_version(f"{_STATS_DETAIL_PREFIX}{academy_id}:")
    if user_id is not None:
        await app_cache.bump_prefix_version(f"{_STATS_ME_PREFIX}{user_id}:")


async def create_attendance_session(
    db: AsyncSession,
    *,
    current_user: User,
    title: str | None = None,
    expires_in_minutes: int = 20,
) -> AttendanceSession:
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")
    if not current_user.academy_id and current_user.role != "administrador":
        raise ForbiddenError("Usuário não está vinculado a uma academia.")

    starts_at = _now_utc()
    expires_at = starts_at + timedelta(minutes=int(expires_in_minutes or 20))
    s = AttendanceSession(
        academy_id=current_user.academy_id,
        created_by_user_id=current_user.id,
        status="active",
        title=(title.strip() if isinstance(title, str) and title.strip() else None),
        starts_at=starts_at,
        ends_at=None,
        expires_at=expires_at,
    )
    db.add(s)
    await db.commit()
    await db.refresh(s)
    return s


async def close_attendance_session(
    db: AsyncSession,
    session_id: UUID,
    *,
    current_user: User,
) -> AttendanceSession:
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")

    s = await db.get(AttendanceSession, session_id)
    if not s:
        raise AttendanceSessionNotFoundError()
    verify_academy_access(current_user, str(s.academy_id) if s.academy_id else None, allow_none=True)
    if s.status != "closed":
        s.status = "closed"
        s.ends_at = _now_utc()
        await db.commit()
        await db.refresh(s)
    return s


async def get_attendance_session(
    db: AsyncSession,
    session_id: UUID,
    *,
    current_user: User,
) -> tuple[AttendanceSession, int]:
    s = await get_attendance_session_basic(
        db, session_id, current_user=current_user
    )
    present_count = (
        await db.execute(
            select(func.count(AttendanceRecord.id)).where(AttendanceRecord.session_id == session_id)
        )
    ).scalar_one()
    return s, int(present_count or 0)


async def get_attendance_session_basic(
    db: AsyncSession,
    session_id: UUID,
    *,
    current_user: User,
) -> AttendanceSession:
    s = await db.get(AttendanceSession, session_id)
    if not s:
        raise AttendanceSessionNotFoundError()
    verify_academy_access(current_user, str(s.academy_id) if s.academy_id else None, allow_none=True)
    return s


async def list_attendance_sessions(
    db: AsyncSession,
    *,
    current_user: User,
    status: str | None = None,
    mine: bool = False,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[tuple[AttendanceSession, int]]:
    """Lista sessões de presença (professor/gerente: academia; admin: todas)."""
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")

    if status is not None and status.strip().lower() not in ("active", "closed"):
        raise AppError("Parâmetro status inválido. Use active ou closed.", status_code=400)

    present_subq = (
        select(
            AttendanceRecord.session_id.label("sid"),
            func.count(AttendanceRecord.id).label("pc"),
        ).group_by(AttendanceRecord.session_id)
    ).subquery()

    conds: list = []
    if current_user.role != "administrador":
        if not current_user.academy_id:
            raise ForbiddenError("Usuário não está vinculado a uma academia.")
        conds.append(AttendanceSession.academy_id == current_user.academy_id)

    if status:
        conds.append(AttendanceSession.status == status.strip().lower())
    if mine:
        conds.append(AttendanceSession.created_by_user_id == current_user.id)
    if date_from is not None:
        conds.append(AttendanceSession.starts_at >= date_from)
    if date_to is not None:
        conds.append(AttendanceSession.starts_at <= date_to)

    stmt = (
        select(
            AttendanceSession,
            func.coalesce(present_subq.c.pc, 0).label("present_count"),
        )
        .outerjoin(present_subq, present_subq.c.sid == AttendanceSession.id)
        .order_by(AttendanceSession.starts_at.desc())
        .limit(clamp_list_limit(limit))
        .offset(offset)
    )
    if conds:
        stmt = stmt.where(*conds)

    rows = (await db.execute(stmt)).all()
    return [(row[0], int(row[1] or 0)) for row in rows]


async def add_record_manual(
    db: AsyncSession,
    *,
    current_user: User,
    session_id: UUID,
    target_user_id: UUID,
) -> tuple[AttendanceRecord, bool]:
    """Adiciona presença manual (sem QR). Idempotente por (session_id, user_id)."""
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")

    s = await db.get(AttendanceSession, session_id)
    if not s:
        raise AttendanceSessionNotFoundError()
    verify_academy_access(current_user, str(s.academy_id) if s.academy_id else None, allow_none=True)

    _target_row = (await db.execute(
        select(User.role, User.academy_id).where(User.id == target_user_id)
    )).one_or_none()
    if _target_row is None:
        raise UserNotFoundError()
    if _target_row[0] != "aluno":
        raise ForbiddenError("Apenas alunos podem receber presença nesta sessão.")

    if s.academy_id is not None:
        if _target_row[1] != s.academy_id:
            raise ForbiddenError("O aluno não pertence à mesma academia desta sessão.")
    else:
        if current_user.role != "administrador":
            if not current_user.academy_id or _target_row[1] != current_user.academy_id:
                raise ForbiddenError("O aluno não está na sua academia.")

    existing = (
        await db.execute(
            select(AttendanceRecord).where(
                AttendanceRecord.session_id == session_id,
                AttendanceRecord.user_id == target_user_id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        return existing, False

    now = _now_utc()
    r = AttendanceRecord(
        session_id=session_id,
        user_id=target_user_id,
        checked_in_at=now,
        method="manual",
        added_manually=True,
    )
    db.add(r)
    await db.commit()
    await db.refresh(r)
    await invalidate_attendance_ranking_cache(s.academy_id)
    await invalidate_attendance_stats_cache(s.academy_id, target_user_id)
    return r, True


async def delete_attendance_record(
    db: AsyncSession,
    *,
    current_user: User,
    record_id: UUID,
) -> tuple[UUID, UUID]:
    """Remove um registo de presença. Retorna (session_id, user_id) para broadcast WS."""
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")

    r = await db.get(AttendanceRecord, record_id)
    if not r:
        raise AttendanceRecordNotFoundError()

    s = await db.get(AttendanceSession, r.session_id)
    if not s:
        raise AttendanceSessionNotFoundError()

    verify_academy_access(current_user, str(s.academy_id) if s.academy_id else None, allow_none=True)

    session_id = r.session_id
    user_id = r.user_id
    await db.delete(r)
    await db.commit()
    await invalidate_attendance_ranking_cache(s.academy_id)
    await invalidate_attendance_stats_cache(s.academy_id, user_id)
    return session_id, user_id


async def scan_checkin(
    db: AsyncSession,
    *,
    current_user: User,
    token: str,
) -> tuple[AttendanceRecord, bool]:
    """Registra presença via token QR. Idempotente por (session_id, user_id)."""
    from app.services.qr_service import verify as qr_verify, verify_short as qr_verify_short
    from app.core.exceptions import AttendanceQrInvalidError

    if current_user.role not in ("aluno", "professor", "gerente_academia"):
        raise ForbiddenError("Apenas alunos, professores e gerentes podem registrar presença via QR.")
    if not current_user.academy_id:
        raise ForbiddenError("Usuário não está vinculado a uma academia.")

    stripped = token.strip()
    if len(stripped) == 5:
        session_id = qr_verify_short(stripped)
    else:
        session_id = qr_verify(stripped)

    now = _now_utc()

    # Busca apenas as colunas necessárias — evita carregar relacionamentos selectin
    # (created_by, records, etc.) que disparam cascatas de queries e podem falhar.
    _s_row = (
        await db.execute(
            select(
                AttendanceSession.id,
                AttendanceSession.academy_id,
                AttendanceSession.status,
                AttendanceSession.expires_at,
            ).where(AttendanceSession.id == session_id)
        )
    ).one_or_none()
    if _s_row is None:
        raise AttendanceSessionNotFoundError()

    s_academy_id = _s_row[1]
    s_status = _s_row[2]
    s_expires_at = _s_row[3]

    if s_academy_id is not None:
        qr_enabled = (
            await db.execute(
                select(Academy.qr_attendance_enabled).where(Academy.id == s_academy_id)
            )
        ).scalar_one_or_none()
        if qr_enabled is False:
            raise ForbiddenError(
                "A chamada por QR está desativada para esta academia. Faça presença manual."
            )
    if s_status != "active":
        raise AttendanceSessionClosedError()
    if s_expires_at and s_expires_at < now:
        raise AttendanceSessionClosedError("Sessão expirada.")
    if s_academy_id and s_academy_id != current_user.academy_id:
        raise ForbiddenError("Acesso negado. Sessão pertence a outra academia.")

    existing = (
        await db.execute(
            select(AttendanceRecord).where(
                AttendanceRecord.session_id == session_id,
                AttendanceRecord.user_id == current_user.id,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        return existing, False

    r = AttendanceRecord(
        session_id=session_id,
        user_id=current_user.id,
        checked_in_at=now,
        method="qr",
        added_manually=False,
    )
    db.add(r)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raced = (
            await db.execute(
                select(AttendanceRecord).where(
                    AttendanceRecord.session_id == session_id,
                    AttendanceRecord.user_id == current_user.id,
                )
            )
        ).scalar_one_or_none()
        if raced is not None:
            return raced, False
        raise

    await invalidate_attendance_ranking_cache(s_academy_id)
    await invalidate_attendance_stats_cache(s_academy_id, current_user.id)
    return r, True


async def user_summary(
    db: AsyncSession,
    *,
    user_id: UUID,
    from_dt: datetime,
    to_dt: datetime,
    current_user: User,
) -> tuple[int, datetime | None]:
    # Permissão: professor/gerente/admin; ou o próprio aluno.
    if current_user.role == "aluno" and current_user.id != user_id:
        raise ForbiddenError("Acesso negado.")
    if current_user.role not in ("aluno", "administrador", "gerente_academia", "professor", "supervisor"):
        raise ForbiddenError("Acesso negado.")

    _target_academy_row = (await db.execute(
        select(User.academy_id).where(User.id == user_id)
    )).one_or_none()
    if _target_academy_row is None:
        raise UserNotFoundError()

    verify_academy_access(
        current_user,
        str(_target_academy_row[0]) if _target_academy_row[0] else None,
        allow_none=True,
    )

    q = (
        select(func.count(AttendanceRecord.id), func.max(AttendanceRecord.checked_in_at))
        .where(AttendanceRecord.user_id == user_id)
        .where(AttendanceRecord.checked_in_at >= from_dt)
        .where(AttendanceRecord.checked_in_at <= to_dt)
    )
    count, last_seen = (await db.execute(q)).one()
    return int(count or 0), last_seen


def _default_stats_date_range(
    date_from: datetime | None,
    date_to: datetime | None,
) -> tuple[datetime, datetime]:
    """Intervalo padrão para estatísticas: últimos 30 dias até agora (UTC)."""
    to_dt = date_to or _now_utc()
    from_dt = date_from or (to_dt - timedelta(days=30))
    return from_dt, to_dt


class AttendanceStudentStatRow(NamedTuple):
    user_id: UUID
    email: str
    name: str | None
    graduation: str | None
    present_count: int
    last_seen_at: datetime | None
    attendance_rate: float


class AttendanceRecordWithSessionRow(NamedTuple):
    id: UUID
    session_id: UUID
    session_title: str | None
    session_starts_at: datetime
    checked_in_at: datetime
    method: str
    face_recognition: bool


class AttendanceStudentDetailResult(NamedTuple):
    user_id: UUID
    email: str
    name: str | None
    graduation: str | None
    present_count: int
    total_sessions: int
    attendance_rate: float
    last_seen_at: datetime | None
    records: list[AttendanceRecordWithSessionRow]


async def stats_sessions_by_professor(
    db: AsyncSession,
    *,
    current_user: User,
    professor_id: UUID | None,
    date_from: datetime | None,
    date_to: datetime | None,
    limit: int = 200,
) -> list[tuple[AttendanceSession, int]]:
    """Sessões criadas por um professor no período, com contagem de presentes."""
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")

    pid = professor_id or current_user.id
    if current_user.role == "professor" and pid != current_user.id:
        raise ForbiddenError("Acesso negado.")

    if current_user.role == "gerente_academia":
        _prof_row = (await db.execute(
            select(User.academy_id).where(User.id == pid)
        )).one_or_none()
        if _prof_row is None or _prof_row[0] != current_user.academy_id:
            raise ForbiddenError("Professor inválido para esta academia.")

    df, dt = _default_stats_date_range(date_from, date_to)

    present_subq = (
        select(
            AttendanceRecord.session_id.label("sid"),
            func.count(AttendanceRecord.id).label("pc"),
        ).group_by(AttendanceRecord.session_id)
    ).subquery()

    stmt = (
        select(
            AttendanceSession,
            func.coalesce(present_subq.c.pc, 0).label("present_count"),
        )
        .outerjoin(present_subq, present_subq.c.sid == AttendanceSession.id)
        .where(
            AttendanceSession.created_by_user_id == pid,
            AttendanceSession.starts_at >= df,
            AttendanceSession.starts_at <= dt,
        )
        .order_by(AttendanceSession.starts_at.desc())
        .limit(clamp_list_limit(limit))
    )

    if current_user.role != "administrador":
        if not current_user.academy_id:
            raise ForbiddenError("Usuário não está vinculado a uma academia.")
        stmt = stmt.where(AttendanceSession.academy_id == current_user.academy_id)

    rows = (await db.execute(stmt)).all()
    return [(row[0], int(row[1] or 0)) for row in rows]


async def stats_students(
    db: AsyncSession,
    *,
    current_user: User,
    academy_id: UUID | None,
    date_from: datetime | None,
    date_to: datetime | None,
    limit: int = 500,
) -> tuple[int, list[AttendanceStudentStatRow]]:
    """Total de sessões da academia no período + frequência por aluno."""
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")

    aid = academy_id or current_user.academy_id
    if aid is None:
        raise AppError("Informe academy_id (administrador sem academia vinculada).", status_code=400)

    if current_user.role != "administrador":
        if not current_user.academy_id:
            raise ForbiddenError("Usuário não está vinculado a uma academia.")
        if aid != current_user.academy_id:
            raise ForbiddenError("academy_id inválido para o seu perfil.")

    verify_academy_access(current_user, str(aid), allow_none=False)

    df, dt = _default_stats_date_range(date_from, date_to)

    total_n = (
        await db.execute(
            select(func.count(AttendanceSession.id)).where(
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
        )
    ).scalar_one()
    total_sessions = int(total_n or 0)

    agg_subq = (
        select(
            AttendanceRecord.user_id.label("uid"),
            func.count(AttendanceRecord.id).label("pc"),
            func.max(AttendanceRecord.checked_in_at).label("last_seen"),
        )
        .select_from(AttendanceRecord)
        .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
        .where(
            AttendanceSession.academy_id == aid,
            AttendanceSession.starts_at >= df,
            AttendanceSession.starts_at <= dt,
        )
        .group_by(AttendanceRecord.user_id)
    ).subquery()

    lim = clamp_list_limit(limit)
    stmt = (
        select(
            User.id,
            User.email,
            User.name,
            User.graduation,
            func.coalesce(agg_subq.c.pc, 0).label("present_count"),
            agg_subq.c.last_seen,
        )
        .select_from(User)
        .outerjoin(agg_subq, User.id == agg_subq.c.uid)
        .where(User.academy_id == aid, User.role == "aluno")
        .order_by(User.name.asc().nullslast(), User.email.asc())
        .limit(lim)
    )

    rows = (await db.execute(stmt)).all()
    out: list[AttendanceStudentStatRow] = []
    for row in rows:
        uid, email, name, grad, pc, last_seen = row
        pc_i = int(pc or 0)
        rate = (pc_i / total_sessions) if total_sessions else 0.0
        if rate > 1.0:
            rate = 1.0
        out.append(
            AttendanceStudentStatRow(
                user_id=uid,
                email=email,
                name=name,
                graduation=grad,
                present_count=pc_i,
                last_seen_at=last_seen,
                attendance_rate=rate,
            )
        )
    return total_sessions, out


async def stats_student_detail(
    db: AsyncSession,
    *,
    current_user: User,
    student_id: UUID,
    academy_id: UUID | None,
    date_from: datetime | None,
    date_to: datetime | None,
    records_limit: int = 500,
) -> AttendanceStudentDetailResult:
    """Detalhe de frequência de um aluno + lista de presenças no período."""
    target = await db.get(User, student_id)
    if not target or target.role != "aluno":
        raise UserNotFoundError("Aluno não encontrado.")

    aid = academy_id or target.academy_id
    if aid is None:
        raise ForbiddenError("Aluno sem academia.")

    if current_user.role not in ("aluno", "administrador", "gerente_academia", "professor", "supervisor"):
        raise ForbiddenError("Acesso negado.")
    if current_user.role == "aluno" and current_user.id != student_id:
        raise ForbiddenError("Acesso negado.")

    verify_academy_access(current_user, str(aid), allow_none=False)

    if target.academy_id != aid:
        raise ForbiddenError("academy_id não corresponde ao aluno.")

    df, dt = _default_stats_date_range(date_from, date_to)

    _detail_cache_key = await app_cache.versioned_key(
        f"{_STATS_DETAIL_PREFIX}{aid}:",
        f"{student_id}:{df.isoformat()}:{dt.isoformat()}:{records_limit}",
    )
    _detail_cached = await app_cache.get(_detail_cache_key)
    if _detail_cached is not None:
        return _detail_cached

    total_n = (
        await db.execute(
            select(func.count(AttendanceSession.id)).where(
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
        )
    ).scalar_one()
    total_sessions = int(total_n or 0)

    agg = (
        await db.execute(
            select(
                func.count(AttendanceRecord.id),
                func.max(AttendanceRecord.checked_in_at),
            )
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(
                AttendanceRecord.user_id == student_id,
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
        )
    ).one()
    present_count, last_seen = int(agg[0] or 0), agg[1]
    rate = (present_count / total_sessions) if total_sessions else 0.0
    if rate > 1.0:
        rate = 1.0

    lim = clamp_list_limit(records_limit)
    rec_rows = (
        await db.execute(
            select(
                AttendanceRecord.id,
                AttendanceRecord.session_id,
                AttendanceSession.title,
                AttendanceSession.starts_at,
                AttendanceRecord.checked_in_at,
                AttendanceRecord.method,
                AttendanceRecord.face_recognition,
            )
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(
                AttendanceRecord.user_id == student_id,
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
            .order_by(AttendanceRecord.checked_in_at.desc())
            .limit(lim)
        )
    ).all()

    records = [
        AttendanceRecordWithSessionRow(
            id=r[0],
            session_id=r[1],
            session_title=r[2],
            session_starts_at=r[3],
            checked_in_at=r[4],
            method=r[5],
            face_recognition=bool(r[6]),
        )
        for r in rec_rows
    ]

    result = AttendanceStudentDetailResult(
        user_id=target.id,
        email=target.email,
        name=target.name,
        graduation=target.graduation,
        present_count=present_count,
        total_sessions=total_sessions,
        attendance_rate=rate,
        last_seen_at=last_seen,
        records=records,
    )
    await app_cache.set(_detail_cache_key, result, ttl=_STATS_DETAIL_TTL_SEC)
    return result


def _monday_of_date(d: date) -> date:
    return d - timedelta(days=d.weekday())


def _first_of_month(d: date) -> date:
    return date(d.year, d.month, 1)


def _month_add1(d: date) -> date:
    if d.month == 12:
        return date(d.year + 1, 1, 1)
    return date(d.year, d.month + 1, 1)


def _month_sub1(d: date) -> date:
    if d.month == 1:
        return date(d.year - 1, 12, 1)
    return date(d.year, d.month - 1, 1)


def _last_day_of_month(d: date) -> date:
    nxt = _month_add1(date(d.year, d.month, 1))
    return nxt - timedelta(days=1)


def _week_label(week_start: date) -> str:
    iso = week_start.isocalendar()
    return f"{iso.year}-W{iso.week:02d}"


def _month_label(month_start: date) -> str:
    return f"{month_start.year}-{month_start.month:02d}"


def _norm_trunc_to_bucket_start(bstart: datetime, bucket: Literal["week", "month"]) -> date:
    d = bstart.date() if isinstance(bstart, datetime) else bstart
    if bucket == "week":
        return _monday_of_date(d)
    return _first_of_month(d)


def _build_checkins_by_period(
    bucket: Literal["week", "month"],
    df: datetime,
    dt: datetime,
    raw_counts: dict[date, int],
) -> list[tuple[date, date, str, int]]:
    """Lista ordenada de buckets no intervalo [df, dt] com present_count (zeros preenchidos)."""
    out: list[tuple[date, date, str, int]] = []
    d0, d1 = df.date(), dt.date()
    if bucket == "week":
        cur = _monday_of_date(d0)
        end_week = _monday_of_date(d1)
        while cur <= end_week:
            pend = cur + timedelta(days=6)
            out.append((cur, pend, _week_label(cur), raw_counts.get(cur, 0)))
            cur += timedelta(days=7)
    else:
        cur = _first_of_month(d0)
        end_m = _first_of_month(d1)
        while cur <= end_m:
            pend = _last_day_of_month(cur)
            out.append((cur, pend, _month_label(cur), raw_counts.get(cur, 0)))
            cur = _month_add1(cur)
    return out


class AttendanceMyStatsData(NamedTuple):
    from_dt: datetime
    to_dt: datetime
    bucket: Literal["week", "month"]
    total_sessions: int
    total_checkins: int
    percentage: float
    last_seen_at: datetime | None
    lifetime_total_sessions: int
    lifetime_total_checkins: int
    lifetime_percentage: float
    checkins_by_period: list[tuple[date, date, str, int]]
    history_rows: list[AttendanceRecordWithSessionRow]
    history_total: int
    history_limit: int
    history_offset: int


class AttendanceRankingSqlRow(NamedTuple):
    student_id: UUID
    name: str | None
    email: str
    belt: str | None
    total_checkins: int
    position: int


class AttendanceRankingRow(NamedTuple):
    position: int
    student_id: UUID
    name: str
    avatar_url: str | None
    belt: str | None
    total_checkins: int
    attendance_percentage: int
    position_change: int | None


class AttendanceMyPositionRow(NamedTuple):
    position: int
    total_checkins: int
    attendance_percentage: int
    position_change: int | None


class AttendanceRankingResult(NamedTuple):
    month: str | None
    period_kind: Literal["month", "quarter", "year", "custom"]
    period_label: str
    period_start: date
    period_end: date
    ranking: list[AttendanceRankingRow]
    my_position: AttendanceMyPositionRow | None


class AttendanceRankingPeriodWindow(NamedTuple):
    kind: Literal["month", "quarter", "year", "custom"]
    label: str
    start: datetime
    end: datetime
    start_date: date
    end_date: date
    prev_start: datetime | None
    prev_end: datetime | None


def _parse_ranking_month(month: str | None, *, default_month: date | None = None) -> date:
    if month is None or not month.strip():
        base = default_month or _now_utc().date()
        return date(base.year, base.month, 1)
    try:
        parsed = datetime.strptime(month.strip(), "%Y-%m").date()
        return date(parsed.year, parsed.month, 1)
    except ValueError as exc:
        raise AppError("Parâmetro month inválido. Use YYYY-MM.", status_code=400) from exc


def _month_range_utc(month_start: date) -> tuple[datetime, datetime]:
    start = datetime(month_start.year, month_start.month, 1, tzinfo=timezone.utc)
    nxt = _month_add1(month_start)
    end = datetime(nxt.year, nxt.month, 1, tzinfo=timezone.utc)
    return start, end


def _year_range_utc(year_value: int) -> tuple[datetime, datetime]:
    start = datetime(year_value, 1, 1, tzinfo=timezone.utc)
    end = datetime(year_value + 1, 1, 1, tzinfo=timezone.utc)
    return start, end


def _quarter_start_date(year_value: int, quarter_value: int) -> date:
    month_value = ((quarter_value - 1) * 3) + 1
    return date(year_value, month_value, 1)


def _quarter_range_utc(year_value: int, quarter_value: int) -> tuple[datetime, datetime]:
    start_date = _quarter_start_date(year_value, quarter_value)
    if quarter_value == 4:
        next_start = _quarter_start_date(year_value + 1, 1)
    else:
        next_start = _quarter_start_date(year_value, quarter_value + 1)
    start = datetime(start_date.year, start_date.month, start_date.day, tzinfo=timezone.utc)
    end = datetime(next_start.year, next_start.month, next_start.day, tzinfo=timezone.utc)
    return start, end


def _custom_range_utc(date_from: date, date_to: date) -> tuple[datetime, datetime]:
    start = datetime(date_from.year, date_from.month, date_from.day, tzinfo=timezone.utc)
    next_day = date_to + timedelta(days=1)
    end = datetime(next_day.year, next_day.month, next_day.day, tzinfo=timezone.utc)
    return start, end


def _resolve_ranking_period_window(
    *,
    period: Literal["month", "quarter", "year", "custom"],
    month: str | None,
    year: int | None,
    quarter: int | None,
    date_from: date | None,
    date_to: date | None,
) -> AttendanceRankingPeriodWindow:
    now = _now_utc().date()
    period_kind = period.strip().lower()
    if period_kind not in {"month", "quarter", "year", "custom"}:
        raise AppError("Parâmetro period inválido. Use month, quarter, year ou custom.", status_code=400)

    if period_kind == "month":
        month_start = _parse_ranking_month(month, default_month=now)
        start, end = _month_range_utc(month_start)
        prev_month_start = _month_sub1(month_start)
        prev_start, prev_end = _month_range_utc(prev_month_start)
        return AttendanceRankingPeriodWindow(
            kind="month",
            label=_month_label(month_start),
            start=start,
            end=end,
            start_date=month_start,
            end_date=_month_add1(month_start) - timedelta(days=1),
            prev_start=prev_start,
            prev_end=prev_end,
        )

    if period_kind == "quarter":
        year_value = year or now.year
        quarter_value = quarter or (((now.month - 1) // 3) + 1)
        if quarter_value < 1 or quarter_value > 4:
            raise AppError("Parâmetro quarter inválido. Use 1, 2, 3 ou 4.", status_code=400)
        start, end = _quarter_range_utc(year_value, quarter_value)
        if quarter_value == 1:
            prev_year = year_value - 1
            prev_quarter = 4
        else:
            prev_year = year_value
            prev_quarter = quarter_value - 1
        prev_start, prev_end = _quarter_range_utc(prev_year, prev_quarter)
        start_date = _quarter_start_date(year_value, quarter_value)
        return AttendanceRankingPeriodWindow(
            kind="quarter",
            label=f"{year_value}-Q{quarter_value}",
            start=start,
            end=end,
            start_date=start_date,
            end_date=(end - timedelta(days=1)).date(),
            prev_start=prev_start,
            prev_end=prev_end,
        )

    if period_kind == "year":
        year_value = year or now.year
        start, end = _year_range_utc(year_value)
        prev_start, prev_end = _year_range_utc(year_value - 1)
        return AttendanceRankingPeriodWindow(
            kind="year",
            label=f"{year_value}",
            start=start,
            end=end,
            start_date=date(year_value, 1, 1),
            end_date=date(year_value, 12, 31),
            prev_start=prev_start,
            prev_end=prev_end,
        )

    if date_from is None or date_to is None:
        raise AppError("Para period=custom, informe date_from e date_to (YYYY-MM-DD).", status_code=400)
    if date_from > date_to:
        raise AppError("date_from não pode ser maior que date_to.", status_code=400)
    span_days = (date_to - date_from).days + 1
    if span_days > 366:
        raise AppError("Intervalo custom excede o máximo de 366 dias.", status_code=400)
    start, end = _custom_range_utc(date_from, date_to)
    return AttendanceRankingPeriodWindow(
        kind="custom",
        label=f"{date_from.isoformat()}_{date_to.isoformat()}",
        start=start,
        end=end,
        start_date=date_from,
        end_date=date_to,
        prev_start=None,
        prev_end=None,
    )


def _attendance_percentage_int(total_checkins: int, total_sessions: int) -> int:
    if total_sessions <= 0:
        return 0
    pct = round((total_checkins / total_sessions) * 100)
    return max(0, min(int(pct), 100))


async def _ranking_rows_for_range(
    db: AsyncSession,
    *,
    academy_id: UUID,
    range_start: datetime,
    range_end: datetime,
) -> list[AttendanceRankingSqlRow]:
    counts_subq = (
        select(
            AttendanceRecord.user_id.label("student_id"),
            func.count(AttendanceRecord.id).label("total_checkins"),
        )
        .select_from(AttendanceRecord)
        .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
        .join(User, User.id == AttendanceRecord.user_id)
        .where(
            AttendanceSession.academy_id == academy_id,
            AttendanceSession.starts_at >= range_start,
            AttendanceSession.starts_at < range_end,
            User.academy_id == academy_id,
            User.role == "aluno",
        )
        .group_by(AttendanceRecord.user_id)
        .subquery()
    )

    name_sort = func.lower(func.coalesce(func.nullif(func.trim(User.name), ""), User.email))
    ranked_stmt = (
        select(
            counts_subq.c.student_id,
            User.name,
            User.email,
            User.graduation.label("belt"),
            counts_subq.c.total_checkins,
            func.row_number()
            .over(
                order_by=(
                    counts_subq.c.total_checkins.desc(),
                    name_sort.asc(),
                    User.email.asc(),
                )
            )
            .label("position"),
        )
        .select_from(counts_subq)
        .join(User, User.id == counts_subq.c.student_id)
        .order_by("position")
    )

    rows = (await db.execute(ranked_stmt)).all()
    return [
        AttendanceRankingSqlRow(
            student_id=row[0],
            name=row[1],
            email=row[2],
            belt=row[3],
            total_checkins=int(row[4] or 0),
            position=int(row[5] or 0),
        )
        for row in rows
    ]


def _decode_ranking_result(d: dict) -> "AttendanceRankingResult":
    return AttendanceRankingResult(
        month=d["month"],
        period_kind=d["period_kind"],
        period_label=d["period_label"],
        period_start=date.fromisoformat(d["period_start"]),
        period_end=date.fromisoformat(d["period_end"]),
        ranking=[
            AttendanceRankingRow(
                position=r["position"],
                student_id=UUID(r["student_id"]),
                name=r["name"],
                avatar_url=r["avatar_url"],
                belt=r["belt"],
                total_checkins=r["total_checkins"],
                attendance_percentage=r["attendance_percentage"],
                position_change=r["position_change"],
            )
            for r in d["ranking"]
        ],
        my_position=AttendanceMyPositionRow(
            position=d["my_position"]["position"],
            total_checkins=d["my_position"]["total_checkins"],
            attendance_percentage=d["my_position"]["attendance_percentage"],
            position_change=d["my_position"]["position_change"],
        ) if d.get("my_position") is not None else None,
    )


async def attendance_ranking(
    db: AsyncSession,
    *,
    current_user: User,
    academy_id: UUID | None,
    period: Literal["month", "quarter", "year", "custom"] = "month",
    month: str | None = None,
    year: int | None = None,
    quarter: int | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    limit: int = 10,
) -> AttendanceRankingResult:
    aid = academy_id or current_user.academy_id
    if aid is None:
        raise AppError("Informe academy_id (administrador sem academia vinculada).", status_code=400)

    if current_user.role != "administrador":
        if not current_user.academy_id:
            raise ForbiddenError("Usuário não está vinculado a uma academia.")
        if aid != current_user.academy_id:
            raise ForbiddenError("academy_id inválido para o seu perfil.")

    verify_academy_access(current_user, str(aid), allow_none=False)

    window = _resolve_ranking_period_window(
        period=period,
        month=month,
        year=year,
        quarter=quarter,
        date_from=date_from,
        date_to=date_to,
    )
    lim = min(max(limit, 1), 10)
    cache_prefix = f"{_ATTENDANCE_RANKING_PREFIX}{aid}:"
    cache_key = await app_cache.versioned_key(
        cache_prefix,
        f"{current_user.id}:{window.kind}:{window.label}:{lim}",
    )
    cached = await app_cache.get(cache_key)
    if cached is not None:
        if isinstance(cached, AttendanceRankingResult):
            return cached
        if isinstance(cached, dict) and cached.get("_type") == "AttendanceRankingResult":
            try:
                return _decode_ranking_result(cached)
            except Exception:
                pass  # dados corrompidos no cache — re-consulta o banco

    total_sessions_raw = (
        await db.execute(
            select(func.count(AttendanceSession.id)).where(
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= window.start,
                AttendanceSession.starts_at < window.end,
            )
        )
    ).scalar_one()
    total_sessions = int(total_sessions_raw or 0)

    current_rows = await _ranking_rows_for_range(
        db,
        academy_id=aid,
        range_start=window.start,
        range_end=window.end,
    )
    prev_rows: list[AttendanceRankingSqlRow] = []
    if window.prev_start is not None and window.prev_end is not None:
        prev_rows = await _ranking_rows_for_range(
            db,
            academy_id=aid,
            range_start=window.prev_start,
            range_end=window.prev_end,
        )
    prev_pos_by_student = {r.student_id: r.position for r in prev_rows}

    ranking: list[AttendanceRankingRow] = []
    my_position: AttendanceMyPositionRow | None = None

    for row in current_rows:
        if window.kind == "custom":
            position_change = None
        else:
            prev_pos = prev_pos_by_student.get(row.student_id)
            position_change = None if prev_pos is None else int(prev_pos - row.position)
        pct = _attendance_percentage_int(row.total_checkins, total_sessions)
        display_name = (row.name or "").strip() or row.email

        if row.position <= lim:
            ranking.append(
                AttendanceRankingRow(
                    position=row.position,
                    student_id=row.student_id,
                    name=display_name,
                    avatar_url=None,
                    belt=row.belt,
                    total_checkins=row.total_checkins,
                    attendance_percentage=pct,
                    position_change=position_change,
                )
            )

        if row.student_id == current_user.id:
            my_position = AttendanceMyPositionRow(
                position=row.position,
                total_checkins=row.total_checkins,
                attendance_percentage=pct,
                position_change=position_change,
            )

    result = AttendanceRankingResult(
        month=window.label if window.kind == "month" else None,
        period_kind=window.kind,
        period_label=window.label,
        period_start=window.start_date,
        period_end=window.end_date,
        ranking=ranking,
        my_position=my_position,
    )
    cache_payload = {
        "_type": "AttendanceRankingResult",
        "month": result.month,
        "period_kind": result.period_kind,
        "period_label": result.period_label,
        "period_start": result.period_start.isoformat(),
        "period_end": result.period_end.isoformat(),
        "ranking": [
            {
                "position": r.position,
                "student_id": str(r.student_id),
                "name": r.name,
                "avatar_url": r.avatar_url,
                "belt": r.belt,
                "total_checkins": r.total_checkins,
                "attendance_percentage": r.attendance_percentage,
                "position_change": r.position_change,
            }
            for r in result.ranking
        ],
        "my_position": {
            "position": result.my_position.position,
            "total_checkins": result.my_position.total_checkins,
            "attendance_percentage": result.my_position.attendance_percentage,
            "position_change": result.my_position.position_change,
        } if result.my_position is not None else None,
    }
    await app_cache.set(cache_key, cache_payload, ttl=_ATTENDANCE_RANKING_TTL_SEC)
    return result


async def stats_me(
    db: AsyncSession,
    *,
    current_user: User,
    date_from: datetime | None,
    date_to: datetime | None,
    history_limit: int = 30,
    history_offset: int = 0,
) -> AttendanceMyStatsData:
    """Estatísticas de presença do utilizador logado na própria academia."""
    if current_user.academy_id is None:
        raise NotFoundError("Utilizador não está vinculado a uma academia.")

    aid = current_user.academy_id
    verify_academy_access(current_user, str(aid), allow_none=False)

    df, dt = _default_stats_date_range(date_from, date_to)
    if df > dt:
        df, dt = dt, df

    lim = min(max(history_limit, 1), 100)
    off = max(history_offset, 0)
    _me_cache_key = await app_cache.versioned_key(
        f"{_STATS_ME_PREFIX}{current_user.id}:",
        f"{df.isoformat()}:{dt.isoformat()}:{lim}:{off}",
    )
    _me_cached = await app_cache.get(_me_cache_key)
    if _me_cached is not None:
        return _me_cached

    span_days = (dt - df).days
    bucket_pg: Literal["week", "month"] = "week" if span_days <= 60 else "month"

    total_n = (
        await db.execute(
            select(func.count(AttendanceSession.id)).where(
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
        )
    ).scalar_one()
    total_sessions = int(total_n or 0)

    period_agg = (
        await db.execute(
            select(
                func.count(AttendanceRecord.id),
                func.max(AttendanceRecord.checked_in_at),
            )
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(
                AttendanceRecord.user_id == current_user.id,
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
        )
    ).one()
    total_checkins = int(period_agg[0] or 0)
    last_seen_at: datetime | None = period_agg[1]

    percentage = (total_checkins / total_sessions) if total_sessions else 0.0
    if percentage > 1.0:
        percentage = 1.0

    lt_sess_n = (
        await db.execute(
            select(func.count(AttendanceSession.id)).where(AttendanceSession.academy_id == aid)
        )
    ).scalar_one()
    lifetime_total_sessions = int(lt_sess_n or 0)

    lt_agg = (
        await db.execute(
            select(
                func.count(AttendanceRecord.id),
                func.max(AttendanceRecord.checked_in_at),
            )
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(
                AttendanceRecord.user_id == current_user.id,
                AttendanceSession.academy_id == aid,
            )
        )
    ).one()
    lifetime_total_checkins = int(lt_agg[0] or 0)
    lifetime_last_seen: datetime | None = lt_agg[1]

    lifetime_percentage = (
        (lifetime_total_checkins / lifetime_total_sessions) if lifetime_total_sessions else 0.0
    )
    if lifetime_percentage > 1.0:
        lifetime_percentage = 1.0

    trunc = func.date_trunc(bucket_pg, AttendanceSession.starts_at)
    bucket_rows = (
        await db.execute(
            select(trunc.label("bstart"), func.count(AttendanceRecord.id).label("pc"))
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(
                AttendanceRecord.user_id == current_user.id,
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
            .group_by(trunc)
            .order_by(trunc.asc())
        )
    ).all()

    raw_counts: dict[date, int] = {}
    for row in bucket_rows:
        bstart, pc = row[0], row[1]
        key = _norm_trunc_to_bucket_start(bstart, bucket_pg)
        raw_counts[key] = int(pc or 0)

    checkins_by_period = _build_checkins_by_period(bucket_pg, df, dt, raw_counts)

    hist_total_n = (
        await db.execute(
            select(func.count(AttendanceRecord.id))
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(
                AttendanceRecord.user_id == current_user.id,
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
        )
    ).scalar_one()
    history_total = int(hist_total_n or 0)

    rec_rows = (
        await db.execute(
            select(
                AttendanceRecord.id,
                AttendanceRecord.session_id,
                AttendanceSession.title,
                AttendanceSession.starts_at,
                AttendanceRecord.checked_in_at,
                AttendanceRecord.method,
                AttendanceRecord.face_recognition,
            )
            .select_from(AttendanceRecord)
            .join(AttendanceSession, AttendanceSession.id == AttendanceRecord.session_id)
            .where(
                AttendanceRecord.user_id == current_user.id,
                AttendanceSession.academy_id == aid,
                AttendanceSession.starts_at >= df,
                AttendanceSession.starts_at <= dt,
            )
            .order_by(AttendanceRecord.checked_in_at.desc())
            .limit(lim)
            .offset(off)
        )
    ).all()

    history_rows = [
        AttendanceRecordWithSessionRow(
            id=r[0],
            session_id=r[1],
            session_title=r[2],
            session_starts_at=r[3],
            checked_in_at=r[4],
            method=r[5],
            face_recognition=bool(r[6]),
        )
        for r in rec_rows
    ]

    result = AttendanceMyStatsData(
        from_dt=df,
        to_dt=dt,
        bucket=bucket_pg,
        total_sessions=total_sessions,
        total_checkins=total_checkins,
        percentage=percentage,
        last_seen_at=lifetime_last_seen or last_seen_at,
        lifetime_total_sessions=lifetime_total_sessions,
        lifetime_total_checkins=lifetime_total_checkins,
        lifetime_percentage=lifetime_percentage,
        checkins_by_period=checkins_by_period,
        history_rows=history_rows,
        history_total=history_total,
        history_limit=lim,
        history_offset=off,
    )
    await app_cache.set(_me_cache_key, result, ttl=_STATS_ME_TTL_SEC)
    return result

