"""Lógica de negócio para convites de auto-cadastro e fila de aprovação."""

from __future__ import annotations

import secrets
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ConflictError
from app.core.security import hash_password
from app.models import Academy, User
from app.models.enrollment_invite import EnrollmentInvite, PendingEnrollment
from app.services.user_service import create_user, get_user_by_email

# ---------------------------------------------------------------------------
# Convite (token/QR)
# ---------------------------------------------------------------------------

async def get_or_create_invite(db: AsyncSession, academy_id: UUID) -> EnrollmentInvite:
    """Retorna o convite ativo da academia ou cria um novo."""
    stmt = select(EnrollmentInvite).where(
        EnrollmentInvite.academy_id == academy_id,
        EnrollmentInvite.is_active == True,  # noqa: E712
    )
    invite = (await db.execute(stmt)).scalar_one_or_none()
    if invite:
        return invite

    invite = EnrollmentInvite(
        academy_id=academy_id,
        token=secrets.token_urlsafe(32),
        is_active=True,
    )
    db.add(invite)
    await db.commit()
    await db.refresh(invite)
    return invite


async def rotate_invite(db: AsyncSession, academy_id: UUID) -> EnrollmentInvite:
    """Desativa o convite atual e gera um novo token."""
    stmt = select(EnrollmentInvite).where(
        EnrollmentInvite.academy_id == academy_id,
        EnrollmentInvite.is_active == True,  # noqa: E712
    )
    old = (await db.execute(stmt)).scalar_one_or_none()
    if old:
        old.is_active = False

    new_invite = EnrollmentInvite(
        academy_id=academy_id,
        token=secrets.token_urlsafe(32),
        is_active=True,
    )
    db.add(new_invite)
    await db.commit()
    await db.refresh(new_invite)
    return new_invite


# ---------------------------------------------------------------------------
# Acesso público ao link
# ---------------------------------------------------------------------------

async def get_invite_by_token(db: AsyncSession, token: str) -> EnrollmentInvite | None:
    stmt = (
        select(EnrollmentInvite)
        .where(EnrollmentInvite.token == token, EnrollmentInvite.is_active == True)  # noqa: E712
    )
    return (await db.execute(stmt)).scalar_one_or_none()


async def get_academy_by_invite_token(db: AsyncSession, token: str) -> Academy | None:
    invite = await get_invite_by_token(db, token)
    if not invite:
        return None
    return (await db.execute(select(Academy).where(Academy.id == invite.academy_id))).scalar_one_or_none()


# ---------------------------------------------------------------------------
# Envio do formulário (aluno)
# ---------------------------------------------------------------------------

async def submit_enrollment(
    db: AsyncSession,
    token: str,
    name: str,
    email: str,
    password: str,
    phone: str | None = None,
    graduation: str | None = None,
) -> PendingEnrollment:
    invite = await get_invite_by_token(db, token)
    if not invite:
        raise AppError("Link de convite inválido ou desativado.", status_code=404)

    email_lower = email.strip().lower()

    # Verifica se já existe user com esse email
    if await get_user_by_email(db, email_lower):
        raise ConflictError("Este e-mail já possui cadastro no sistema.")

    # Verifica duplicata na fila pendente da mesma academia
    dup = (
        await db.execute(
            select(PendingEnrollment).where(
                PendingEnrollment.academy_id == invite.academy_id,
                PendingEnrollment.email == email_lower,
                PendingEnrollment.status == "pending",
            )
        )
    ).scalar_one_or_none()
    if dup:
        raise ConflictError("Já existe uma solicitação pendente com este e-mail.")

    enrollment = PendingEnrollment(
        invite_id=invite.id,
        academy_id=invite.academy_id,
        name=name.strip(),
        email=email_lower,
        phone=phone.strip() if phone else None,
        graduation=graduation.strip() if graduation else None,
        password_hash=await hash_password(password),
        status="pending",
    )
    db.add(enrollment)
    await db.commit()
    await db.refresh(enrollment)
    return enrollment


# ---------------------------------------------------------------------------
# Fila de aprovação (gestor)
# ---------------------------------------------------------------------------

async def list_pending(
    db: AsyncSession,
    academy_id: UUID,
    status: str = "pending",
) -> list[PendingEnrollment]:
    stmt = (
        select(PendingEnrollment)
        .where(
            PendingEnrollment.academy_id == academy_id,
            PendingEnrollment.status == status,
        )
        .order_by(PendingEnrollment.created_at)
    )
    return list((await db.execute(stmt)).scalars().all())


async def approve_enrollment(
    db: AsyncSession,
    enrollment_id: UUID,
    academy_id: UUID,
    *,
    approver_id: UUID,
) -> User:
    enrollment = await _get_enrollment_or_raise(db, enrollment_id, academy_id)
    if enrollment.status != "pending":
        raise AppError("Solicitação já foi processada.", status_code=409)

    # Cria o usuário com a senha que o aluno escolheu
    user = await create_user(
        db,
        email=enrollment.email,
        name=enrollment.name,
        graduation=enrollment.graduation,
        academy_id=academy_id,
        role="aluno",
        audit_user_id=approver_id,
    )
    # Aplica o hash já gerado (evita re-hash)
    user.password_hash = enrollment.password_hash
    enrollment.status = "approved"
    await db.commit()
    return user


async def reject_enrollment(
    db: AsyncSession,
    enrollment_id: UUID,
    academy_id: UUID,
    reason: str | None = None,
) -> PendingEnrollment:
    enrollment = await _get_enrollment_or_raise(db, enrollment_id, academy_id)
    if enrollment.status != "pending":
        raise AppError("Solicitação já foi processada.", status_code=409)

    enrollment.status = "rejected"
    enrollment.rejection_reason = reason
    await db.commit()
    await db.refresh(enrollment)
    return enrollment


async def _get_enrollment_or_raise(
    db: AsyncSession, enrollment_id: UUID, academy_id: UUID
) -> PendingEnrollment:
    stmt = select(PendingEnrollment).where(
        PendingEnrollment.id == enrollment_id,
        PendingEnrollment.academy_id == academy_id,
    )
    enrollment = (await db.execute(stmt)).scalar_one_or_none()
    if not enrollment:
        raise AppError("Solicitação não encontrada.", status_code=404)
    return enrollment
