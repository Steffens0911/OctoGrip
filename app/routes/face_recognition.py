import logging
import os
from datetime import UTC, datetime
from pathlib import Path
from uuid import UUID, uuid4

from fastapi import APIRouter, Body, Depends, File, Form, Query, Request, UploadFile
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.attributes import flag_modified

from app.config import settings
from app.core.auth_deps import get_current_user
from app.core.exceptions import (
    AppError,
    AttendanceSessionNotFoundError,
    ForbiddenError,
    UserNotFoundError,
)
from app.core.rate_limit import limiter
from app.core.role_deps import require_admin_or_manager, require_write_access, verify_academy_access
from app.database import get_db
from app.models import (
    Academy,
    AttendanceRecord,
    AttendanceSession,
    FaceRecognitionJob,
    StudentFaceEmbedding,
    User,
)
from app.schemas.attendance import AttendanceRecordRead
from app.schemas.face_recognition import (
    FaceRecognitionConfirmRequest,
    FaceRecognitionConfirmResponse,
    FaceRecognitionEmbeddingStatusRead,
    FaceRecognitionEmbeddingStatusStudentRead,
    FaceRecognitionJobStatusRead,
    FaceRecognitionSubmitResponse,
)
from app.services.attendance_realtime import attendance_manager
from app.tasks.face_recognition_tasks import generate_student_embedding, process_face_recognition

router = APIRouter()
logger = logging.getLogger(__name__)

_MAX_UPLOAD_BYTES = 15 * 1024 * 1024


def _jobs_dir() -> Path:
    path = Path(settings.FACE_JOBS_DIR)
    try:
        path.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        logger.exception("Falha ao criar FACE_JOBS_DIR=%s", str(path))
        raise AppError(
            "Falha ao preparar diretório temporário de processamento de face.",
            status_code=500,
        ) from exc
    return path


async def _read_image_upload(file: UploadFile) -> bytes:
    content = await file.read()
    if not content:
        raise AppError("Ficheiro de imagem vazio.", status_code=400)
    if len(content) > _MAX_UPLOAD_BYTES:
        raise AppError("Imagem excede 15MB.", status_code=413)
    ctype = (file.content_type or "").lower()
    if ctype not in ("image/jpeg", "image/jpg", "image/png"):
        raise AppError("Formato inválido. Use JPEG ou PNG.", status_code=400)
    return content


async def _get_session_for_face(
    db: AsyncSession,
    *,
    session_id: UUID,
    current_user: User,
) -> AttendanceSession:
    session = await db.get(AttendanceSession, session_id)
    if not session:
        raise AttendanceSessionNotFoundError()
    verify_academy_access(
        current_user,
        str(session.academy_id) if session.academy_id else None,
        allow_none=True,
    )
    if not session.academy_id:
        raise AppError("Sessão sem academia vinculada.", status_code=400)
    academy = await db.get(Academy, session.academy_id)
    if academy is None or not academy.face_recognition_enabled:
        raise ForbiddenError("Reconhecimento facial não está ativo nesta academia.")
    return session


async def _present_count_for_session(db: AsyncSession, session_id: UUID) -> int:
    n = (
        await db.execute(
            select(func.count(AttendanceRecord.id)).where(AttendanceRecord.session_id == session_id)
        )
    ).scalar_one()
    return int(n or 0)


@router.post("/submit", response_model=FaceRecognitionSubmitResponse)
@limiter.limit("5/minute")
async def face_recognition_submit(
    request: Request,
    session_id: str = Form(...),
    photo: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    try:
        session_uuid = UUID(session_id)
    except ValueError as exc:
        raise AppError("session_id inválido.", status_code=422) from exc

    session = await _get_session_for_face(db, session_id=session_uuid, current_user=current_user)
    content = await _read_image_upload(photo)
    job_id = uuid4()
    ext = ".png" if (photo.content_type or "").lower() == "image/png" else ".jpg"
    photo_path = _jobs_dir() / f"{job_id}{ext}"
    try:
        photo_path.write_bytes(content)
    except OSError as exc:
        logger.exception("Falha ao gravar foto do job %s em %s", str(job_id), str(photo_path))
        raise AppError(
            "Falha ao gravar a foto para processamento. Tente novamente em instantes.",
            status_code=500,
        ) from exc

    job = FaceRecognitionJob(
        id=job_id,
        session_id=session.id,
        academy_id=session.academy_id,
        created_by_user_id=current_user.id,
        status="pending",
        photo_path=str(photo_path),
    )
    db.add(job)
    await db.commit()
    try:
        process_face_recognition.delay(str(job_id))
    except Exception as exc:  # noqa: BLE001 - queremos capturar falhas do broker/enqueue
        logger.exception("Falha ao enfileirar processamento do job %s", str(job_id))
        job.status = "failed"
        job.error_message = "Falha ao enfileirar o processamento. Tente novamente."
        await db.commit()
        raise AppError(
            "Falha ao iniciar o processamento. Tente novamente em instantes.",
            status_code=503,
        ) from exc

    return FaceRecognitionSubmitResponse(
        job_id=job_id,
        status="pending",
        message="Foto recebida. Você será notificado quando o processamento terminar.",
    )


@router.get("/job/{job_id}", response_model=FaceRecognitionJobStatusRead)
async def face_recognition_job_status(
    job_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    job = await db.get(FaceRecognitionJob, job_id)
    if not job:
        raise AppError("Job não encontrado.", status_code=404)
    verify_academy_access(
        current_user,
        str(job.academy_id) if job.academy_id else None,
        allow_none=True,
    )
    payload = job.result_json or {}
    return FaceRecognitionJobStatusRead(
        job_id=job.id,
        status=job.status,
        session_id=job.session_id,
        total_faces_detected=payload.get("total_faces_detected"),
        results=payload.get("results"),
        error_message=job.error_message,
        reference_photo_base64=payload.get("reference_photo_base64"),
    )


@router.post("/confirm", response_model=FaceRecognitionConfirmResponse)
@limiter.limit("5/minute")
async def face_recognition_confirm(
    request: Request,
    body: FaceRecognitionConfirmRequest = Body(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    session = await _get_session_for_face(db, session_id=body.session_id, current_user=current_user)
    job = await db.get(FaceRecognitionJob, body.job_id)
    if not job:
        raise AppError("Job não encontrado.", status_code=404)
    if job.session_id != session.id:
        raise AppError("Job não pertence à sessão informada.", status_code=400)

    created_records: list[AttendanceRecord] = []
    unique_student_ids = list(dict.fromkeys(body.confirmed_student_ids))
    for student_id in unique_student_ids:
        student = await db.get(User, student_id)
        if not student:
            raise UserNotFoundError()
        if student.role != "aluno":
            raise ForbiddenError("Apenas alunos podem receber presença via reconhecimento facial.")
        if student.academy_id != session.academy_id:
            raise ForbiddenError("Aluno não pertence à academia da sessão.")

        existing = (
            await db.execute(
                select(AttendanceRecord).where(
                    AttendanceRecord.session_id == session.id,
                    AttendanceRecord.user_id == student.id,
                )
            )
        ).scalar_one_or_none()
        if existing:
            if existing.method != "face":
                existing.method = "face"
            existing.face_recognition = True
            continue

        record = AttendanceRecord(
            session_id=session.id,
            user_id=student.id,
            checked_in_at=datetime.now(UTC),
            method="face",
            face_recognition=True,
            added_manually=False,
        )
        db.add(record)
        created_records.append(record)

    await db.commit()
    for record in created_records:
        await db.refresh(record)
        present_count = await _present_count_for_session(db, record.session_id)
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
            record.session_id,
            {
                "type": "checkin",
                "session_id": str(record.session_id),
                "record": rec_read.model_dump(mode="json"),
                "present_count": present_count,
            },
        )

    job_updated = await db.get(FaceRecognitionJob, body.job_id)
    if job_updated and isinstance(job_updated.result_json, dict):
        cleaned = dict(job_updated.result_json)
        cleaned.pop("reference_photo_base64", None)
        job_updated.result_json = cleaned
        flag_modified(job_updated, "result_json")
        await db.commit()

    if job.photo_path:
        try:
            os.remove(job.photo_path)
        except OSError:
            pass

    return FaceRecognitionConfirmResponse(
        session_id=session.id,
        job_id=job.id,
        created_records=len(created_records),
        records=[
            {
                "id": str(r.id),
                "session_id": str(r.session_id),
                "user_id": str(r.user_id),
                "checked_in_at": r.checked_in_at.isoformat(),
                "method": r.method,
                "face_recognition": r.face_recognition,
            }
            for r in created_records
        ],
    )


@router.post("/generate-embedding/{student_id}")
@limiter.limit("5/minute")
async def face_generate_embedding(
    request: Request,
    student_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager),
):
    student = await db.get(User, student_id)
    if not student:
        raise UserNotFoundError()
    if student.role != "aluno":
        raise ForbiddenError("Apenas alunos possuem embedding facial.")
    verify_academy_access(
        current_user,
        str(student.academy_id) if student.academy_id else None,
        allow_none=False,
    )
    if not student.avatar_url:
        raise AppError("Aluno sem avatar_url cadastrado.", status_code=400)

    generate_student_embedding.delay(str(student.id))
    return {"status": "queued", "student_id": str(student.id)}


@router.get("/embedding-status", response_model=FaceRecognitionEmbeddingStatusRead)
async def face_embedding_status(
    academy_id: UUID | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_manager),
):
    target_academy_id = academy_id or current_user.academy_id
    if not target_academy_id:
        raise AppError("academy_id é obrigatório para este utilizador.", status_code=400)
    verify_academy_access(current_user, str(target_academy_id), allow_none=False)

    students = (
        await db.execute(
            select(User)
            .where(User.academy_id == target_academy_id, User.role == "aluno")
            .order_by(User.name.asc().nulls_last(), User.email.asc())
        )
    ).scalars().all()
    emb_rows = (
        await db.execute(
            select(
                StudentFaceEmbedding.student_id,
                StudentFaceEmbedding.updated_at,
            ).where(StudentFaceEmbedding.academy_id == target_academy_id)
        )
    ).all()
    emb_map = {row[0]: row[1] for row in emb_rows}
    payload = [
        FaceRecognitionEmbeddingStatusStudentRead(
            student_id=s.id,
            name=s.name,
            email=s.email,
            avatar_url=s.avatar_url,
            has_embedding=s.id in emb_map,
            updated_at=emb_map.get(s.id),
        )
        for s in students
    ]
    with_embedding = sum(1 for p in payload if p.has_embedding)
    return FaceRecognitionEmbeddingStatusRead(
        academy_id=target_academy_id,
        total_students=len(payload),
        with_embedding=with_embedding,
        without_embedding=len(payload) - with_embedding,
        students=payload,
    )
