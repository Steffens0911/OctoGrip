"""CRUD de professores (seção professor)."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, ProfessorNotFoundError
from app.core.role_deps import require_admin_or_academy_access, verify_academy_access
from app.database import get_db
from app.models import Professor, User
from app.schemas.professor import ProfessorCreate, ProfessorRead, ProfessorUpdate
from app.services.professor_service import (
    create_professor,
    delete_professor,
    get_professor,
    list_professors,
    update_professor,
)

router = APIRouter()


@router.get("", response_model=list[ProfessorRead])
async def professors_list(
    academy_id: UUID | None = Query(None, description="Filtrar por academia"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Lista professores."""
    if current_user.role != "administrador" and academy_id:
        verify_academy_access(current_user, str(academy_id))
    elif current_user.role != "administrador":
        academy_id = current_user.academy_id
    return await list_professors(db, academy_id=academy_id)


@router.get("/{professor_id}", response_model=ProfessorRead)
async def professor_get(
    professor_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Retorna um professor por ID."""
    professor = await get_professor(db, professor_id)
    if not professor:
        raise ProfessorNotFoundError()
    verify_academy_access(current_user, str(professor.academy_id) if professor.academy_id else None)
    return professor


@router.post("", response_model=ProfessorRead, status_code=201)
async def professor_create(
    body: ProfessorCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Cria um professor (e-mail único)."""
    if current_user.role != "administrador":
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia para criar professores.")
        body.academy_id = current_user.academy_id
    elif body.academy_id:
        verify_academy_access(current_user, str(body.academy_id))
    existing = (
        await db.execute(select(Professor).where(Professor.email == body.email))
    ).scalar_one_or_none()
    if existing:
        raise ConflictError("E-mail já cadastrado.")
    return await create_professor(
        db,
        name=body.name,
        email=body.email,
        academy_id=body.academy_id,
    )


@router.patch("/{professor_id}", response_model=ProfessorRead)
async def professor_update(
    professor_id: UUID,
    body: ProfessorUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Atualiza um professor."""
    professor = await get_professor(db, professor_id)
    if not professor:
        raise ProfessorNotFoundError()
    verify_academy_access(current_user, str(professor.academy_id) if professor.academy_id else None)
    payload = body.model_dump(exclude_unset=True)
    if current_user.role != "administrador":
        payload.pop("academy_id", None)
    elif "academy_id" in payload and payload["academy_id"]:
        verify_academy_access(current_user, str(payload["academy_id"]))
    updated = await update_professor(
        db,
        professor_id,
        name=payload.get("name"),
        email=payload.get("email"),
        academy_id=payload.get("academy_id"),
    )
    if not updated:
        raise ProfessorNotFoundError()
    return updated


@router.delete("/{professor_id}", status_code=204)
async def professor_delete(
    professor_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Remove um professor."""
    if not await delete_professor(db, professor_id):
        raise ProfessorNotFoundError()
    return None
