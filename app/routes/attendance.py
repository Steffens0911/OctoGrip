from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response, WebSocket, WebSocketDisconnect
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.auth_deps import get_current_user, require_aluno_not_frozen
from app.core.list_pagination import MAX_LIST_LIMIT
from app.core.rate_limit import limiter
from app.core.role_deps import require_read_access, require_write_access
from app.core.security import decode_access_token
from app.database import get_db
from app.models import AttendanceRecord, AttendanceSession, User
from app.schemas.attendance import (
    AttendanceManualBatchResponse,
    AttendanceManualCheckinRequest,
    AttendanceMyPositionRead,
    AttendanceMyStatsRead,
    AttendancePeriodBucketRead,
    AttendanceQrPayloadResponse,
    AttendanceRankingEntryRead,
    AttendanceRankingRead,
    AttendanceRecordRead,
    AttendanceRecordWithSessionRead,
    AttendanceScanRequest,
    AttendanceSessionCreate,
    AttendanceSessionRead,
    AttendanceSessionStatRead,
    AttendanceStudentDetailRead,
    AttendanceStudentStatRead,
    AttendanceUserSummaryResponse,
)
from app.services.attendance_realtime import attendance_manager
from app.services.attendance_service import (
    add_record_manual,
    attendance_ranking as attendance_ranking_service,
    close_attendance_session,
    create_attendance_session,
    delete_attendance_record,
    get_attendance_session,
    get_attendance_session_basic,
    issue_qr_payload,
    list_attendance_sessions,
    scan_checkin,
    stats_me,
    stats_sessions_by_professor,
    stats_student_detail,
    stats_students,
    user_summary,
)
from app.services.user_service import get_user

router = APIRouter()


async def _present_count_for_session(db: AsyncSession, session_id: UUID) -> int:
    n = (
        await db.execute(
            select(func.count(AttendanceRecord.id)).where(AttendanceRecord.session_id == session_id)
        )
    ).scalar_one()
    return int(n or 0)


def _record_read(r: AttendanceRecord) -> AttendanceRecordRead:
    return AttendanceRecordRead(
        id=r.id,
        session_id=r.session_id,
        user_id=r.user_id,
        checked_in_at=r.checked_in_at,
        method=r.method,
        face_recognition=r.face_recognition,
        added_manually=r.added_manually,
    )


@router.get("/stats/sessions", response_model=list[AttendanceSessionStatRead])
async def attendance_stats_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
    professor_id: UUID | None = Query(None, description="Default: utilizador atual. Admin pode filtrar outro."),
    date_from: datetime | None = Query(None, alias="from"),
    date_to: datetime | None = Query(None, alias="to"),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT),
):
    rows = await stats_sessions_by_professor(
        db,
        current_user=current_user,
        professor_id=professor_id,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
    )
    return [
        AttendanceSessionStatRead(
            id=s.id,
            title=s.title,
            starts_at=s.starts_at,
            ends_at=s.ends_at,
            status=s.status,
            present_count=count,
        )
        for s, count in rows
    ]


@router.get("/stats/students", response_model=list[AttendanceStudentStatRead])
async def attendance_stats_students(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
    academy_id: UUID | None = Query(None),
    date_from: datetime | None = Query(None, alias="from"),
    date_to: datetime | None = Query(None, alias="to"),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT),
):
    total_sessions, rows = await stats_students(
        db,
        current_user=current_user,
        academy_id=academy_id,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
    )
    return [
        AttendanceStudentStatRead(
            user_id=r.user_id,
            email=r.email,
            name=r.name,
            graduation=r.graduation,
            present_count=r.present_count,
            total_sessions=total_sessions,
            attendance_rate=r.attendance_rate,
            last_seen_at=r.last_seen_at,
        )
        for r in rows
    ]


@router.get("/ranking", response_model=AttendanceRankingRead)
async def attendance_get_ranking(
    academy_id: UUID | None = Query(None),
    period: Literal["month", "quarter", "year", "custom"] = Query(
        "month", description="month | quarter | year | custom"
    ),
    month: str | None = Query(None, description="Formato YYYY-MM (usado em period=month)"),
    year: int | None = Query(None, ge=2000, le=2100, description="Ano para period=quarter/year"),
    quarter: int | None = Query(None, ge=1, le=4, description="Trimestre 1..4 (usado em period=quarter)"),
    date_from: date | None = Query(None, description="Início YYYY-MM-DD (usado em period=custom)"),
    date_to: date | None = Query(None, description="Fim YYYY-MM-DD (usado em period=custom)"),
    limit: int = Query(10, ge=1, le=10),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    data = await attendance_ranking_service(
        db,
        current_user=current_user,
        academy_id=academy_id,
        period=period,  # validated in service with clear 400 errors
        month=month,
        year=year,
        quarter=quarter,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
    )
    return AttendanceRankingRead(
        month=data.month,
        period_kind=data.period_kind,
        period_label=data.period_label,
        period_start=data.period_start,
        period_end=data.period_end,
        ranking=[
            AttendanceRankingEntryRead(
                position=r.position,
                student_id=r.student_id,
                name=r.name,
                avatar_url=r.avatar_url,
                belt=r.belt,
                total_checkins=r.total_checkins,
                attendance_percentage=r.attendance_percentage,
                position_change=r.position_change,
            )
            for r in data.ranking
        ],
        my_position=(
            AttendanceMyPositionRead(
                position=data.my_position.position,
                total_checkins=data.my_position.total_checkins,
                attendance_percentage=data.my_position.attendance_percentage,
                position_change=data.my_position.position_change,
            )
            if data.my_position is not None
            else None
        ),
    )


@router.get("/stats/me", response_model=AttendanceMyStatsRead)
async def attendance_stats_me(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    date_from: datetime | None = Query(None, alias="from"),
    date_to: datetime | None = Query(None, alias="to"),
    limit: int = Query(30, ge=1, le=MAX_LIST_LIMIT),
    offset: int = Query(0, ge=0),
):
    d = await stats_me(
        db,
        current_user=current_user,
        date_from=date_from,
        date_to=date_to,
        history_limit=limit,
        history_offset=offset,
    )
    return AttendanceMyStatsRead(
        from_date=d.from_dt,
        to_date=d.to_dt,
        bucket=d.bucket,
        total_sessions=d.total_sessions,
        total_checkins=d.total_checkins,
        percentage=d.percentage,
        last_seen_at=d.last_seen_at,
        lifetime_total_sessions=d.lifetime_total_sessions,
        lifetime_total_checkins=d.lifetime_total_checkins,
        lifetime_percentage=d.lifetime_percentage,
        checkins_by_period=[
            AttendancePeriodBucketRead(
                period_start=ps,
                period_end=pe,
                label=lb,
                present_count=pc,
            )
            for ps, pe, lb, pc in d.checkins_by_period
        ],
        history=[
            AttendanceRecordWithSessionRead(
                id=r.id,
                session_id=r.session_id,
                session_title=r.session_title,
                session_starts_at=r.session_starts_at,
                checked_in_at=r.checked_in_at,
                method=r.method,
                face_recognition=r.face_recognition,
            )
            for r in d.history_rows
        ],
        history_total=d.history_total,
        history_limit=d.history_limit,
        history_offset=d.history_offset,
    )


@router.get("/stats/students/{student_id}", response_model=AttendanceStudentDetailRead)
async def attendance_stats_student_detail(
    student_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    academy_id: UUID | None = Query(None),
    date_from: datetime | None = Query(None, alias="from"),
    date_to: datetime | None = Query(None, alias="to"),
    records_limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT),
):
    d = await stats_student_detail(
        db,
        current_user=current_user,
        student_id=student_id,
        academy_id=academy_id,
        date_from=date_from,
        date_to=date_to,
        records_limit=records_limit,
    )
    return AttendanceStudentDetailRead(
        user_id=d.user_id,
        email=d.email,
        name=d.name,
        graduation=d.graduation,
        present_count=d.present_count,
        total_sessions=d.total_sessions,
        attendance_rate=d.attendance_rate,
        last_seen_at=d.last_seen_at,
        records=[
            AttendanceRecordWithSessionRead(
                id=r.id,
                session_id=r.session_id,
                session_title=r.session_title,
                session_starts_at=r.session_starts_at,
                checked_in_at=r.checked_in_at,
                method=r.method,
                face_recognition=r.face_recognition,
            )
            for r in d.records
        ],
    )


@router.get("/sessions", response_model=list[AttendanceSessionRead])
async def attendance_sessions_list(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
    status: str | None = Query(None, description="active ou closed"),
    mine: bool = Query(False, description="Apenas sessões criadas pelo utilizador atual."),
    date_from: datetime | None = Query(None, description="Início do intervalo (starts_at >= date_from)."),
    date_to: datetime | None = Query(None, description="Fim do intervalo (starts_at <= date_to)."),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT),
    offset: int = Query(0, ge=0),
):
    rows = await list_attendance_sessions(
        db,
        current_user=current_user,
        status=status,
        mine=mine,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
    return [
        AttendanceSessionRead(
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
        for s, count in rows
    ]


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


@router.post(
    "/sessions/{session_id}/records",
    status_code=201,
)
async def attendance_session_add_record(
    session_id: UUID,
    body: AttendanceManualCheckinRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
) -> AttendanceRecordRead | AttendanceManualBatchResponse:
    if body.student_ids is not None:
        registered: list[AttendanceRecordRead] = []
        for target_user_id in body.student_ids:
            r, created = await add_record_manual(
                db,
                current_user=current_user,
                session_id=session_id,
                target_user_id=target_user_id,
            )
            if not created:
                continue
            present_count = await _present_count_for_session(db, r.session_id)
            rec_read = _record_read(r)
            await attendance_manager.broadcast(
                r.session_id,
                {
                    "type": "checkin",
                    "session_id": str(r.session_id),
                    "record": rec_read.model_dump(mode="json"),
                    "present_count": present_count,
                },
            )
            registered.append(rec_read)
        return AttendanceManualBatchResponse(records=registered)

    assert body.user_id is not None
    r, created = await add_record_manual(
        db,
        current_user=current_user,
        session_id=session_id,
        target_user_id=body.user_id,
    )
    if created:
        present_count = await _present_count_for_session(db, r.session_id)
        rec_read = _record_read(r)
        await attendance_manager.broadcast(
            r.session_id,
            {
                "type": "checkin",
                "session_id": str(r.session_id),
                "record": rec_read.model_dump(mode="json"),
                "present_count": present_count,
            },
        )
    return _record_read(r)


@router.delete("/records/{record_id}", status_code=204)
async def attendance_record_delete(
    record_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    session_id, user_id = await delete_attendance_record(
        db, current_user=current_user, record_id=record_id
    )
    present_count = await _present_count_for_session(db, session_id)
    await attendance_manager.broadcast(
        session_id,
        {
            "type": "record_removed",
            "session_id": str(session_id),
            "record_id": str(record_id),
            "user_id": str(user_id),
            "present_count": present_count,
        },
    )
    return Response(status_code=204)


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
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT),
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
    return [_record_read(r) for r in rows]


@router.get("/sessions/{session_id}/qr", response_model=AttendanceQrPayloadResponse)
async def attendance_session_qr(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
    ttl_seconds: int = Query(60, ge=15, le=180),
):
    await get_attendance_session_basic(db, session_id, current_user=current_user)
    payload, exp = issue_qr_payload(session_id=session_id, ttl_seconds=ttl_seconds)
    return AttendanceQrPayloadResponse(payload=payload, expires_at=exp)


@router.websocket("/sessions/{session_id}/ws")
async def attendance_session_ws(
    websocket: WebSocket,
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
    token: str = Query(..., min_length=10, description="JWT do utilizador (Bearer sem prefixo)."),
):
    """Professor/gestor/admin ouve check-ins em tempo real. Auth via query (limitação de WebSockets)."""
    sub = decode_access_token(token)
    if not sub:
        await websocket.close(code=4001)
        return
    try:
        user_uuid = UUID(sub)
    except ValueError:
        await websocket.close(code=4001)
        return

    user = await get_user(db, user_uuid)
    if not user:
        await websocket.close(code=4001)
        return

    if user.role not in ("administrador", "gerente_academia", "professor"):
        await websocket.close(code=4003)
        return

    s = await db.get(AttendanceSession, session_id)
    if not s:
        await websocket.close(code=4004)
        return

    if s.academy_id and user.role != "administrador" and s.academy_id != user.academy_id:
        await websocket.close(code=4003)
        return

    await websocket.accept()
    await attendance_manager.connect(session_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await attendance_manager.disconnect(session_id, websocket)


@router.post("/scan", response_model=AttendanceRecordRead, status_code=201)
@limiter.limit("30/minute")
async def attendance_scan(
    request: Request,
    body: AttendanceScanRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_aluno_not_frozen),
):
    r, created = await scan_checkin(db, current_user=current_user, payload=body.payload)
    if created:
        present_count = await _present_count_for_session(db, r.session_id)
        rec_read = _record_read(r)
        await attendance_manager.broadcast(
            r.session_id,
            {
                "type": "checkin",
                "session_id": str(r.session_id),
                "record": rec_read.model_dump(mode="json"),
                "present_count": present_count,
            },
        )
    return _record_read(r)


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

