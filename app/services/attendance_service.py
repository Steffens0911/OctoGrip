from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from datetime import date, datetime, timedelta, timezone
from typing import Literal, NamedTuple
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.exceptions import (
    AppError,
    AttendanceQrInvalidError,
    AttendanceRecordNotFoundError,
    AttendanceSessionClosedError,
    AttendanceSessionNotFoundError,
    ForbiddenError,
    NotFoundError,
    UserNotFoundError,
)
from app.core.role_deps import verify_academy_access
from app.models import AttendanceRecord, AttendanceSession, User


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _hmac_sig(secret: str, msg: str) -> str:
    mac = hmac.new(secret.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).digest()
    return _b64url(mac)


def _parse_payload(payload: str) -> dict[str, str]:
    # Formato: sid=...&iat=...&exp=...&nonce=...&sig=...
    parts = [p for p in (payload or "").split("&") if p]
    out: dict[str, str] = {}
    for p in parts:
        if "=" not in p:
            continue
        k, v = p.split("=", 1)
        out[k.strip()] = v.strip()
    return out


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
    s = await db.get(AttendanceSession, session_id)
    if not s:
        raise AttendanceSessionNotFoundError()
    verify_academy_access(current_user, str(s.academy_id) if s.academy_id else None, allow_none=True)
    present_count = (
        await db.execute(
            select(func.count(AttendanceRecord.id)).where(AttendanceRecord.session_id == session_id)
        )
    ).scalar_one()
    return s, int(present_count or 0)


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
        .limit(limit)
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

    target = await db.get(User, target_user_id)
    if not target:
        raise UserNotFoundError()
    if target.role != "aluno":
        raise ForbiddenError("Apenas alunos podem receber presença nesta sessão.")

    if s.academy_id is not None:
        if target.academy_id != s.academy_id:
            raise ForbiddenError("O aluno não pertence à mesma academia desta sessão.")
    else:
        if current_user.role != "administrador":
            if not current_user.academy_id or target.academy_id != current_user.academy_id:
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
    )
    db.add(r)
    await db.commit()
    await db.refresh(r)
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
    return session_id, user_id


def issue_qr_payload(*, session_id: UUID, ttl_seconds: int = 60) -> tuple[str, datetime]:
    now = _now_utc()
    exp = now + timedelta(seconds=int(ttl_seconds))
    nonce = secrets.token_urlsafe(10)

    msg = f"{session_id}|{int(now.timestamp())}|{int(exp.timestamp())}|{nonce}"
    sig = _hmac_sig(settings.ATTENDANCE_QR_SECRET, msg)
    payload = (
        f"sid={session_id}&iat={int(now.timestamp())}&exp={int(exp.timestamp())}"
        f"&nonce={nonce}&sig={sig}"
    )
    return payload, exp


async def scan_checkin(
    db: AsyncSession,
    *,
    current_user: User,
    payload: str,
) -> tuple[AttendanceRecord, bool]:
    if current_user.role != "aluno":
        raise ForbiddenError("Apenas alunos podem registrar presença via QR.")
    if not current_user.academy_id:
        raise ForbiddenError("Aluno não está vinculado a uma academia.")

    data = _parse_payload(payload)
    sid = data.get("sid")
    iat = data.get("iat")
    exp = data.get("exp")
    nonce = data.get("nonce")
    sig = data.get("sig")
    if not (sid and iat and exp and nonce and sig):
        raise AttendanceQrInvalidError()
    try:
        session_id = UUID(sid)
        iat_i = int(iat)
        exp_i = int(exp)
    except Exception:
        raise AttendanceQrInvalidError()

    now = _now_utc()
    if exp_i < int(now.timestamp()):
        raise AttendanceQrInvalidError()
    if exp_i - iat_i > 600:
        # Evita payloads com expiração longa.
        raise AttendanceQrInvalidError()

    msg = f"{session_id}|{iat_i}|{exp_i}|{nonce}"
    expected = _hmac_sig(settings.ATTENDANCE_QR_SECRET, msg)
    if not hmac.compare_digest(expected, sig):
        raise AttendanceQrInvalidError()

    s = await db.get(AttendanceSession, session_id)
    if not s:
        raise AttendanceSessionNotFoundError()
    if s.status != "active":
        raise AttendanceSessionClosedError()
    if s.expires_at and s.expires_at < now:
        raise AttendanceSessionClosedError("Sessão expirada.")
    if s.academy_id and s.academy_id != current_user.academy_id:
        raise ForbiddenError("Acesso negado. Sessão pertence a outra academia.")

    existing = (
        await db.execute(
            select(AttendanceRecord).where(
                AttendanceRecord.session_id == session_id,
                AttendanceRecord.user_id == current_user.id,
            )
        )
    ).scalar_one_or_none()
    if existing:
        return existing, False

    r = AttendanceRecord(
        session_id=session_id,
        user_id=current_user.id,
        checked_in_at=now,
        method="qr",
    )
    db.add(r)
    await db.commit()
    await db.refresh(r)
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

    target = await db.get(User, user_id)
    if not target:
        raise AttendanceQrInvalidError("Usuário não encontrado.")

    verify_academy_access(
        current_user,
        str(target.academy_id) if target.academy_id else None,
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
        prof = await db.get(User, pid)
        if not prof or prof.academy_id != current_user.academy_id:
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
        .limit(min(max(limit, 1), 500))
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

    lim = min(max(limit, 1), 1000)
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

    lim = min(max(records_limit, 1), 1000)
    rec_rows = (
        await db.execute(
            select(
                AttendanceRecord.id,
                AttendanceRecord.session_id,
                AttendanceSession.title,
                AttendanceSession.starts_at,
                AttendanceRecord.checked_in_at,
                AttendanceRecord.method,
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
        )
        for r in rec_rows
    ]

    return AttendanceStudentDetailResult(
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


def _monday_of_date(d: date) -> date:
    return d - timedelta(days=d.weekday())


def _first_of_month(d: date) -> date:
    return date(d.year, d.month, 1)


def _month_add1(d: date) -> date:
    if d.month == 12:
        return date(d.year + 1, 1, 1)
    return date(d.year, d.month + 1, 1)


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

    lim = min(max(history_limit, 1), 100)
    off = max(history_offset, 0)
    rec_rows = (
        await db.execute(
            select(
                AttendanceRecord.id,
                AttendanceRecord.session_id,
                AttendanceSession.title,
                AttendanceSession.starts_at,
                AttendanceRecord.checked_in_at,
                AttendanceRecord.method,
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
        )
        for r in rec_rows
    ]

    return AttendanceMyStatsData(
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

