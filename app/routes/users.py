"""CRUD de usuários. Admin: todos; professor/gerente: própria academia; aluno/outros: só colegas da própria academia."""
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user
from app.core.exceptions import ConflictError, ForbiddenError, UserNotFoundError
from app.core.rate_limit import limiter
from app.core.role_deps import require_admin_or_academy_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.services.user_service import (
    create_user,
    delete_user,
    get_user,
    get_user_by_email,
    get_user_or_raise,
    list_users,
    update_user,
)
from app.services.execution_service import get_points_log, total_points_for_user
from app.services.leveling_service import refresh_user_level

router = APIRouter()

_ALLOWED_NON_ADMIN_CREATE_ROLE = "aluno"


@router.get("", response_model=list[UserRead])
async def users_list(
    db: AsyncSession = Depends(get_db),
    academy_id: UUID | None = Query(None, description="Filtrar por academia (colegas da academia)"),
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(50, ge=1, le=200, description="Limite de resultados (máximo 200)"),
    current_user: User = Depends(get_current_user),
):
    """Lista usuários com paginação."""
    if current_user.role == "administrador":
        return await list_users(db, academy_id=academy_id, offset=offset, limit=limit)
    if current_user.role in ("gerente_academia", "professor"):
        if current_user.academy_id is None:
            return []
        return await list_users(db, academy_id=current_user.academy_id, offset=offset, limit=limit)
    if current_user.academy_id is None:
        raise ForbiddenError("Acesso negado. Você não está vinculado a uma academia.")
    if academy_id is None or academy_id != current_user.academy_id:
        raise ForbiddenError("Acesso negado. Você só pode listar usuários da sua academia.")
    return await list_users(db, academy_id=current_user.academy_id, offset=offset, limit=limit)


@router.get("/{user_id}", response_model=UserRead)
async def user_get(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Obtém um usuário por ID."""
    user = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador" and user.academy_id != current_user.academy_id:
        raise ForbiddenError("Acesso negado. Você só pode acessar usuários da sua academia.")
    return user


@router.get("/{user_id}/points")
async def user_points(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Total de pontos do usuário (execuções confirmadas)."""
    user = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador":
        verify_academy_access(current_user, str(user.academy_id) if user.academy_id else None)
    total_points = await total_points_for_user(db, user_id)
    level, level_points, next_threshold = await refresh_user_level(
        db,
        user_id,
        total_points=total_points,
    )
    return {
        "user_id": user_id,
        "points": total_points,
        "level": level,
        "level_points": level_points,
        "next_level_threshold": next_threshold,
    }


@router.get("/{user_id}/points_log")
async def user_points_log(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    current_user: User = Depends(get_current_user),
):
    """Histórico de pontuação do usuário com paginação."""
    user = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador":
        verify_academy_access(current_user, str(user.academy_id) if user.academy_id else None)
    return {"user_id": user_id, "entries": await get_points_log(db, user_id, limit=limit, offset=offset)}


@router.post("", response_model=UserRead, status_code=201)
@limiter.limit("20/minute")
async def user_create(
    request: Request,
    body: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Cria um usuário (email único)."""
    existing = await get_user_by_email(db, body.email)
    if existing:
        raise ConflictError("E-mail já cadastrado.")
    if current_user.role == "administrador":
        academy_id = body.academy_id
        role = body.role
    else:
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia para cadastrar usuários.")
        academy_id = current_user.academy_id
        role = _ALLOWED_NON_ADMIN_CREATE_ROLE
    return await create_user(
        db,
        email=body.email.strip().lower(),
        name=body.name,
        graduation=body.graduation,
        role=role,
        academy_id=academy_id,
        password=body.password,
    )


@router.patch("/{user_id}", response_model=UserRead)
async def user_update(
    user_id: UUID,
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Atualiza um usuário."""
    target = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador":
        if target.academy_id != current_user.academy_id:
            raise ForbiddenError("Acesso negado. Você só pode editar usuários da sua academia.")
    payload = body.model_dump(exclude_unset=True)
    if current_user.role != "administrador":
        # Endurecimento RBAC: não-admin não pode elevar privilégios nem alterar campos sensíveis.
        payload.pop("role", None)
        payload.pop("academy_id", None)
        payload.pop("points_adjustment", None)
        payload.pop("password", None)
    updated = await update_user(
        db,
        user_id,
        name=payload.get("name"),
        graduation=payload.get("graduation"),
        role=payload.get("role"),
        academy_id=payload.get("academy_id"),
        points_adjustment=payload.get("points_adjustment"),
        password=payload.get("password"),
        gallery_visible=payload.get("gallery_visible"),
    )
    if not updated:
        raise UserNotFoundError()
    return updated


@router.delete("/{user_id}", status_code=204)
async def user_delete(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Exclui o usuário."""
    target = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador" and target.academy_id != current_user.academy_id:
        raise ForbiddenError("Acesso negado. Você só pode excluir usuários da sua academia.")
    if not await delete_user(db, user_id):
        raise UserNotFoundError()
    return None
