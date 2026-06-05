"""Rotas de auto-cadastro via link/QR: públicas e protegidas para gestores."""

from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import AppError, ForbiddenError
from app.database import get_db
from app.models import User
from app.schemas.enrollment_invite import (
    EnrollmentDecision,
    EnrollmentSubmit,
    EnrollmentSubmitResponse,
    InvitePublicInfo,
    InviteRead,
    PendingEnrollmentRead,
)
from app.services import enrollment_service

router = APIRouter()

_MANAGER_ROLES = {"professor", "gerente_academia", "administrador"}


def _require_academy_manager(user: User, academy_id: UUID) -> None:
    if user.role not in _MANAGER_ROLES:
        raise ForbiddenError("Apenas professores e gestores podem acessar este recurso.")
    if user.role != "administrador" and user.academy_id != academy_id:
        raise ForbiddenError("Acesso negado a esta academia.")


# ---------------------------------------------------------------------------
# Públicas (sem autenticação)
# ---------------------------------------------------------------------------


@router.get("/register/{token}", response_model=InvitePublicInfo, tags=["enrollment"])
async def get_invite_info(token: str, db: AsyncSession = Depends(get_db)):
    """Retorna nome da academia para exibir no formulário público."""
    academy = await enrollment_service.get_academy_by_invite_token(db, token)
    if not academy:
        raise AppError("Link inválido ou desativado.", status_code=404)
    return InvitePublicInfo(
        academy_id=academy.id,
        academy_name=academy.name,
        token=token,
    )


@router.post("/register/{token}", response_model=EnrollmentSubmitResponse, tags=["enrollment"])
async def submit_enrollment(
    token: str,
    body: EnrollmentSubmit,
    db: AsyncSession = Depends(get_db),
):
    """Aluno envia seus dados. Ficam pendentes até aprovação do gestor."""
    await enrollment_service.submit_enrollment(
        db,
        token=token,
        name=body.name,
        email=str(body.email),
        password=body.password,
        phone=body.phone,
        graduation=body.graduation,
    )
    return EnrollmentSubmitResponse(message="Solicitação enviada! Aguarde a aprovação da academia.")


# ---------------------------------------------------------------------------
# Protegidas (gestor/professor)
# ---------------------------------------------------------------------------


@router.get(
    "/academies/{academy_id}/enrollment-invite",
    response_model=InviteRead,
    tags=["enrollment"],
)
async def get_or_create_invite(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retorna (ou cria) o token de convite ativo da academia."""
    _require_academy_manager(current_user, academy_id)
    invite = await enrollment_service.get_or_create_invite(db, academy_id)
    return invite


@router.post(
    "/academies/{academy_id}/enrollment-invite/rotate",
    response_model=InviteRead,
    tags=["enrollment"],
)
async def rotate_invite(
    academy_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Invalida o link atual e gera um novo token."""
    _require_academy_manager(current_user, academy_id)
    invite = await enrollment_service.rotate_invite(db, academy_id)
    return invite


@router.get(
    "/academies/{academy_id}/pending-enrollments",
    response_model=list[PendingEnrollmentRead],
    tags=["enrollment"],
)
async def list_pending(
    academy_id: UUID,
    status: str = "pending",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lista solicitações por status: pending | approved | rejected."""
    _require_academy_manager(current_user, academy_id)
    return await enrollment_service.list_pending(db, academy_id, status=status)


@router.post(
    "/academies/{academy_id}/pending-enrollments/{enrollment_id}/decide",
    response_model=dict,
    tags=["enrollment"],
)
async def decide_enrollment(
    academy_id: UUID,
    enrollment_id: UUID,
    body: EnrollmentDecision,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Aprova ou rejeita uma solicitação pendente."""
    _require_academy_manager(current_user, academy_id)

    if body.action == "approve":
        user = await enrollment_service.approve_enrollment(db, enrollment_id, academy_id, approver_id=current_user.id)
        return {"status": "approved", "user_id": str(user.id)}
    else:
        enrollment = await enrollment_service.reject_enrollment(
            db, enrollment_id, academy_id, reason=body.rejection_reason
        )
        return {"status": "rejected", "enrollment_id": str(enrollment.id)}
