"""CRUD de usuários. Admin: todos; professor/gerente: própria academia; aluno/outros: só colegas da própria academia."""
from datetime import date
from pathlib import Path
from typing import Final
from uuid import UUID

from fastapi import APIRouter, Depends, File, Query, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth_deps import get_current_user, require_aluno_not_frozen
from app.core.cache import app_cache
from app.core.exceptions import AppError, ConflictError, ForbiddenError, UserNotFoundError
from app.core.rate_limit import limiter
from app.core.role_deps import require_admin_or_academy_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.schemas.weekly_kit import WeeklyKitChoiceRequest, WeeklyKitChoiceResponse
from app.services.weekly_kit_service import set_user_weekly_kit_choice
from app.services.user_service import (
    UNSET,
    create_user,
    delete_user,
    get_user_by_email,
    get_user_or_raise,
    list_users,
    update_user,
)
from app.services.execution_service import get_points_log, total_points_for_user
from app.services.leveling_service import refresh_user_level
from app.tasks.face_recognition_tasks import generate_student_embedding

router = APIRouter()

_ALLOWED_NON_ADMIN_CREATE_ROLE = "aluno"
_MAX_AVATAR_UPLOAD_BYTES = 5 * 1024 * 1024
_BASE_DIR: Final[Path] = Path(__file__).resolve().parent.parent.parent
_MEDIA_ROOT: Final[Path] = _BASE_DIR / "app_media"
_USER_AVATARS_DIR: Final[Path] = _MEDIA_ROOT / "user_avatars"
_USER_AVATARS_DIR.mkdir(parents=True, exist_ok=True)


async def _read_avatar_upload(file: UploadFile) -> tuple[bytes, str]:
    data = await file.read()
    if not data:
        raise AppError("Arquivo de imagem vazio.", status_code=400)
    if len(data) > _MAX_AVATAR_UPLOAD_BYTES:
        raise AppError("Imagem excede 5MB.", status_code=413)

    allowed = ("image/png", "image/jpeg", "image/jpg", "image/webp")
    content_type = (file.content_type or "").strip().lower()
    if content_type not in allowed:
        name = (file.filename or "").lower()
        if name.endswith(".png"):
            content_type = "image/png"
        elif name.endswith(".jpg") or name.endswith(".jpeg"):
            content_type = "image/jpeg"
        elif name.endswith(".webp"):
            content_type = "image/webp"
    if content_type not in allowed and len(data) >= 12:
        if data[:8] == b"\x89PNG\r\n\x1a\n":
            content_type = "image/png"
        elif data[:2] == b"\xff\xd8":
            content_type = "image/jpeg"
        elif data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            content_type = "image/webp"
    if content_type not in allowed:
        raise AppError("Tipo de arquivo não suportado. Envie PNG, JPEG ou WEBP.", status_code=400)

    extension = ".png"
    if content_type in ("image/jpeg", "image/jpg"):
        extension = ".jpg"
    elif content_type == "image/webp":
        extension = ".webp"
    return data, extension


async def _save_user_avatar_and_maybe_enqueue(
    db: AsyncSession,
    *,
    target: User,
    file: UploadFile,
) -> User:
    data, extension = await _read_avatar_upload(file)
    filename = f"user-{target.id}{extension}"
    dest = _USER_AVATARS_DIR / filename
    dest.write_bytes(data)
    target.avatar_url = f"/media/user_avatars/{filename}"
    await db.commit()
    await db.refresh(target)
    if target.role == "aluno" and target.avatar_url:
        generate_student_embedding.delay(str(target.id))
    return target


@router.put("/me/weekly-kit-choice", response_model=WeeklyKitChoiceResponse)
async def me_weekly_kit_choice(
    body: WeeklyKitChoiceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_aluno_not_frozen),
):
    """Aluno (ou utilizador com academia) escolhe o kit da semana ISO para seguir as missões corretas."""
    if current_user.academy_id is None:
        raise ForbiddenError("Vincule-se a uma academia para escolher um kit semanal.")
    ref: date | None = None
    if body.reference_date:
        ref = date.fromisoformat(body.reference_date)
    row = await set_user_weekly_kit_choice(
        db,
        current_user.id,
        current_user.academy_id,
        body.kit_id,
        reference_date=ref,
    )
    await app_cache.invalidate_prefix(f"mission_week:{current_user.id}:")
    return WeeklyKitChoiceResponse(
        kit_id=row.kit_id,
        iso_week_year=row.iso_week_year,
        iso_week_number=row.iso_week_number,
        academy_id=row.academy_id,
    )


@router.post("/me/avatar", response_model=UserRead)
async def me_upload_avatar(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Faz upload da foto de perfil do utilizador autenticado."""
    target = await get_user_or_raise(db, current_user.id)
    return await _save_user_avatar_and_maybe_enqueue(db, target=target, file=file)


@router.post("/{user_id}/avatar", response_model=UserRead)
async def user_upload_avatar(
    user_id: UUID,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Faz upload da foto de perfil de um utilizador."""
    target = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador" and target.academy_id != current_user.academy_id:
        raise ForbiddenError("Acesso negado. Você só pode editar usuários da sua academia.")
    return await _save_user_avatar_and_maybe_enqueue(db, target=target, file=file)


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
    """Cria um usuário; o e-mail deve ser único em todo o sistema (tabela users), não só na academia."""
    existing = await get_user_by_email(db, body.email)
    if existing:
        raise ConflictError(
            "E-mail já cadastrado por outro usuário (único em todo o sistema)."
        )
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
        audit_user_id=current_user.id,
    )


@router.patch("/{user_id}", response_model=UserRead)
async def user_update(
    user_id: UUID,
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Atualiza um usuário. Se `email` for enviado, deve continuar único em todo o sistema."""
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
    if current_user.role not in ("administrador", "gerente_academia"):
        payload.pop("account_frozen", None)
        payload.pop("account_freeze_reason", None)
    if current_user.role == "gerente_academia":
        if "account_frozen" in payload or "account_freeze_reason" in payload:
            if target.role != "aluno":
                raise ForbiddenError(
                    "Apenas contas de aluno podem ter o congelamento alterado pelo gestor da academia."
                )
            if target.academy_id is None or target.academy_id != current_user.academy_id:
                raise ForbiddenError(
                    "Acesso negado. Só pode congelar alunos vinculados à sua academia."
                )
    updated = await update_user(
        db,
        user_id,
        name=payload.get("name"),
        email=payload.get("email"),
        graduation=payload.get("graduation"),
        role=payload.get("role"),
        academy_id=payload.get("academy_id"),
        points_adjustment=payload.get("points_adjustment"),
        avatar_url=payload.get("avatar_url"),
        password=payload.get("password"),
        gallery_visible=payload.get("gallery_visible"),
        account_frozen=payload["account_frozen"] if "account_frozen" in payload else UNSET,
        account_freeze_reason=payload["account_freeze_reason"]
        if "account_freeze_reason" in payload
        else UNSET,
        audit_user_id=current_user.id,
    )
    if not updated:
        raise UserNotFoundError()
    if "avatar_url" in payload and updated.role == "aluno" and updated.avatar_url:
        generate_student_embedding.delay(str(updated.id))
    return updated


@router.delete("/{user_id}", status_code=204)
async def user_delete(
    user_id: UUID,
    confirm_email: str = Query(
        ...,
        description="Confirmação: repita o e-mail do utilizador a eliminar (irreversível sem backup SQL).",
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Exclui o usuário."""
    target = await get_user_or_raise(db, user_id)
    if current_user.role != "administrador" and target.academy_id != current_user.academy_id:
        raise ForbiddenError("Acesso negado. Você só pode excluir usuários da sua academia.")
    if (confirm_email or "").strip().lower() != (target.email or "").strip().lower():
        raise ForbiddenError(
            "Confirmação inválida: o parâmetro confirm_email deve ser igual ao e-mail do utilizador."
        )
    if not await delete_user(db, user_id, audit_user_id=current_user.id):
        raise UserNotFoundError()
    return None
