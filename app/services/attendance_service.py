from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from typing import Iterable
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.exceptions import (
    AttendanceQrInvalidError,
    AttendanceSessionClosedError,
    AttendanceSessionNotFoundError,
    ForbiddenError,
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
) -> AttendanceRecord:
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
        return existing

    r = AttendanceRecord(
        session_id=session_id,
        user_id=current_user.id,
        checked_in_at=now,
        method="qr",
    )
    db.add(r)
    await db.commit()
    await db.refresh(r)
    return r


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

