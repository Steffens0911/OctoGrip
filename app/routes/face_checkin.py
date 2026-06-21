"""
Quiosque de reconhecimento facial por chegada.

Endpoint público (sem auth header) usado pelo tablet fixo na recepção.
Recebe um frame da câmera, identifica o aluno e registra presença em tempo real.
Frame descartado imediatamente após o embedding ser gerado (LGPD).
"""
import logging
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, File, Request, UploadFile
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, AttendanceSessionNotFoundError, ForbiddenError
from app.core.rate_limit import limiter
from app.database import get_db
from app.models import Academy, AttendanceRecord, AttendanceSession, User
from app.models.training_session import TrainingSession
from app.schemas.attendance import AttendanceRecordRead
from app.schemas.face_checkin import FaceArriveResponse
from app.services.attendance_realtime import attendance_manager
from app.services.face_checkin_service import KIOSK_CONFIDENCE_THRESHOLD, match_face_for_kiosk
from app.services.punctuality_service import apply_punctuality

router = APIRouter()
logger = logging.getLogger(__name__)

_MAX_FRAME_BYTES = 5 * 1024 * 1024  # 5 MB


@router.post("/sessions/{session_id}/face-arrive", response_model=FaceArriveResponse)
@limiter.limit("60/minute")
async def face_arrive(
    request: Request,
    session_id: UUID,
    frame: UploadFile = File(..., description="Frame JPEG/PNG capturado pelo quiosque."),
    db: AsyncSession = Depends(get_db),
):
    """
    Quiosque: identifica o aluno pelo rosto e registra presença automaticamente.

    - Confiança ≥ 0.60 → presença registrada, greeting exibido.
    - Confiança < 0.60 → orienta ao QR Code.
    - Frame descartado imediatamente após processamento.
    """
    session = await db.get(AttendanceSession, session_id)
    if not session:
        raise AttendanceSessionNotFoundError()
    if session.status != "active":
        raise AppError("A chamada não está ativa.", status_code=409)

    academy = await db.get(Academy, session.academy_id) if session.academy_id else None
    if not academy:
        raise AppError("Academia não encontrada.", status_code=400)
    if not academy.face_checkin_enabled:
        raise ForbiddenError("Quiosque facial não está ativo nesta academia.")
    if not academy.face_recognition_enabled:
        raise ForbiddenError("Reconhecimento facial não está habilitado nesta academia.")

    image_bytes = await frame.read()
    if not image_bytes:
        raise AppError("Frame vazio.", status_code=400)
    if len(image_bytes) > _MAX_FRAME_BYTES:
        raise AppError("Frame excede 5 MB.", status_code=413)

    ctype = (frame.content_type or "").lower()
    if ctype not in ("image/jpeg", "image/jpg", "image/png", ""):
        raise AppError("Formato inválido. Use JPEG ou PNG.", status_code=400)

    student, confidence = await match_face_for_kiosk(image_bytes, academy.id, db)
    image_bytes = b""  # Descarta frame imediatamente (LGPD)

    if not student:
        logger.info(
            "kiosk_no_match",
            extra={"session_id": str(session_id), "confidence": round(confidence, 4)},
        )
        return FaceArriveResponse(
            matched=False,
            confidence=round(confidence, 4),
            greeting="Não te reconheci. Use o QR Code.",
        )

    # Verifica duplicata
    existing = (
        await db.execute(
            select(AttendanceRecord).where(
                AttendanceRecord.session_id == session_id,
                AttendanceRecord.user_id == student.id,
            )
        )
    ).scalar_one_or_none()

    if existing:
        name = student.name or "aluno"
        return FaceArriveResponse(
            matched=True,
            confidence=round(confidence, 4),
            student_id=student.id,
            student_name=student.name,
            was_punctual=existing.was_punctual,
            punctuality_streak=student.punctuality_streak,
            xp_awarded=0,
            greeting=f"Olá, {name}! Sua presença já foi registrada.",
            duplicate=True,
        )

    now_utc = datetime.now(UTC)
    record = AttendanceRecord(
        session_id=session_id,
        user_id=student.id,
        checked_in_at=now_utc,
        method="face",
        face_recognition=True,
        added_manually=False,
    )
    db.add(record)

    was_punctual: bool | None = None
    xp_awarded = 0

    if session.training_session_id:
        training_session: TrainingSession | None = await db.get(TrainingSession, session.training_session_id)
        if training_session:
            was_punctual, xp_awarded = await apply_punctuality(
                db,
                user=student,
                academy=academy,
                record=record,
                training_session=training_session,
                checked_in_at=now_utc,
            )

    await db.commit()
    await db.refresh(record)

    # Broadcast para o painel do professor em tempo real
    present_count = (
        await db.execute(
            select(func.count(AttendanceRecord.id)).where(AttendanceRecord.session_id == session_id)
        )
    ).scalar_one()
    rec_read = AttendanceRecordRead(
        id=record.id,
        session_id=record.session_id,
        user_id=record.user_id,
        checked_in_at=record.checked_in_at,
        method=record.method,
        face_recognition=record.face_recognition,
        added_manually=record.added_manually,
    )
    await attendance_manager.broadcast(
        session_id,
        {
            "type": "checkin",
            "session_id": str(session_id),
            "record": rec_read.model_dump(mode="json"),
            "present_count": int(present_count or 0),
        },
    )

    name = student.name or "aluno"
    if was_punctual is True:
        streak = student.punctuality_streak or 0
        if streak > 1:
            greeting = f"Bem-vindo, {name}! ✅ Pontual · 🔥 {streak} seguidos"
        else:
            greeting = f"Bem-vindo, {name}! ✅ Chegou na hora!"
    elif was_punctual is False:
        greeting = f"Bem-vindo, {name}! ⏰ Atrasado hoje — bora focar!"
    else:
        greeting = f"Bem-vindo, {name}! Presença registrada."

    logger.info(
        "kiosk_checkin",
        extra={
            "session_id": str(session_id),
            "student_id": str(student.id),
            "confidence": round(confidence, 4),
            "was_punctual": was_punctual,
            "xp_awarded": xp_awarded,
        },
    )

    return FaceArriveResponse(
        matched=True,
        confidence=round(confidence, 4),
        student_id=student.id,
        student_name=student.name,
        was_punctual=was_punctual,
        punctuality_streak=student.punctuality_streak,
        xp_awarded=xp_awarded,
        greeting=greeting,
        duplicate=False,
    )
