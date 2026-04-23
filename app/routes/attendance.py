from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user, require_aluno_not_frozen
from app.core.role_deps import require_write_access
from app.database import get_db
from app.models import AttendanceRecord, AttendanceSession, User
from app.schemas.attendance import (
    AttendanceQrPayloadResponse,
    AttendanceRecordRead,
    AttendanceScanRequest,
    AttendanceSessionCreate,
    AttendanceSessionRead,
    AttendanceUserSummaryResponse,
)
from app.services.attendance_service import (
    close_attendance_session,
    create_attendance_session,
    get_attendance_session,
    issue_qr_payload,
    scan_checkin,
    user_summary,
)

router = APIRouter()


@router.post("/sessions", response_model=AttendanceSessionRead, status_code=201)
async def attendance_session_create(
    body: AttendanceSessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    s = await create_attendance_session(
        db,
        current_user=current_user,
        title=body.title,
        expires_in_minutes=body.expires_in_minutes or 20,
    )
    return AttendanceSessionRead(
        id=s.id,
        academy_id=s.academy_id,
        created_by_user_id=s.created_by_user_id,
        status=s.status,
        title=s.title,
        starts_at=s.starts_at,
        ends_at=s.ends_at,
        expires_at=s.expires_at,
        present_count=0,
    )


@router.post("/sessions/{session_id}/close", response_model=AttendanceSessionRead)
async def attendance_session_close(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    s = await close_attendance_session(db, session_id, current_user=current_user)
    _, count = await get_attendance_session(db, session_id, current_user=current_user)
    return AttendanceSessionRead(
        id=s.id,
        academy_id=s.academy_id,
        created_by_user_id=s.created_by_user_id,
        status=s.status,
        title=s.title,
        starts_at=s.starts_at,
        ends_at=s.ends_at,
        expires_at=s.expires_at,
        present_count=count,
    )


@router.get("/sessions/{session_id}", response_model=AttendanceSessionRead)
async def attendance_session_get(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    s, count = await get_attendance_session(db, session_id, current_user=current_user)
    return AttendanceSessionRead(
        id=s.id,
        academy_id=s.academy_id,
        created_by_user_id=s.created_by_user_id,
        status=s.status,
        title=s.title,
        starts_at=s.starts_at,
        ends_at=s.ends_at,
        expires_at=s.expires_at,
        present_count=count,
    )


@router.get("/sessions/{session_id}/records", response_model=list[AttendanceRecordRead])
async def attendance_session_records(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = Query(300, ge=1, le=1000),
    offset: int = Query(0, ge=0),
):
    # Reusa validação de acesso de get_attendance_session
    await get_attendance_session(db, session_id, current_user=current_user)
    q = (
        select(AttendanceRecord)
        .where(AttendanceRecord.session_id == session_id)
        .order_by(AttendanceRecord.checked_in_at.asc())
        .limit(limit)
        .offset(offset)
    )
    rows = (await db.execute(q)).scalars().all()
    return [
        AttendanceRecordRead(
            id=r.id,
            session_id=r.session_id,
            user_id=r.user_id,
            checked_in_at=r.checked_in_at,
            method=r.method,
        )
        for r in rows
    ]


@router.get("/sessions/{session_id}/qr", response_model=AttendanceQrPayloadResponse)
async def attendance_session_qr(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
    ttl_seconds: int = Query(60, ge=15, le=180),
):
    await get_attendance_session(db, session_id, current_user=current_user)
    payload, exp = issue_qr_payload(session_id=session_id, ttl_seconds=ttl_seconds)
    return AttendanceQrPayloadResponse(payload=payload, expires_at=exp)


@router.post("/scan", response_model=AttendanceRecordRead, status_code=201)
async def attendance_scan(
    body: AttendanceScanRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_aluno_not_frozen),
):
    r = await scan_checkin(db, current_user=current_user, payload=body.payload)
    return AttendanceRecordRead(
        id=r.id,
        session_id=r.session_id,
        user_id=r.user_id,
        checked_in_at=r.checked_in_at,
        method=r.method,
    )


@router.get("/me/summary", response_model=AttendanceUserSummaryResponse)
async def attendance_me_summary(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    from_days: int = Query(30, ge=1, le=365),
):
    to_dt = datetime.now(timezone.utc)
    from_dt = to_dt - timedelta(days=from_days)
    count, last_seen = await user_summary(
        db,
        user_id=current_user.id,
        from_dt=from_dt,
        to_dt=to_dt,
        current_user=current_user,
    )
    return AttendanceUserSummaryResponse(
        user_id=current_user.id,
        from_dt=from_dt,
        to_dt=to_dt,
        present_count=count,
        last_seen_at=last_seen,
    )


@router.get("/users/{user_id}/summary", response_model=AttendanceUserSummaryResponse)
async def attendance_user_summary(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    from_days: int = Query(30, ge=1, le=365),
):
    to_dt = datetime.now(timezone.utc)
    from_dt = to_dt - timedelta(days=from_days)
    count, last_seen = await user_summary(
        db,
        user_id=user_id,
        from_dt=from_dt,
        to_dt=to_dt,
        current_user=current_user,
    )
    return AttendanceUserSummaryResponse(
        user_id=user_id,
        from_dt=from_dt,
        to_dt=to_dt,
        present_count=count,
        last_seen_at=last_seen,
    )

