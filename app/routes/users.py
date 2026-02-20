"""CRUD de usuários. Admin: todos; professor/gerente: própria academia; aluno/outros: só colegas da própria academia."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.auth_deps import get_current_user
from app.core.role_deps import require_admin_or_academy_access
from app.database import get_db
from app.models import User
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.services.user_service import create_user, delete_user, get_user, get_user_by_email, list_users, update_user
from app.services.execution_service import get_points_log, total_points_for_user

router = APIRouter()


@router.get("", response_model=list[UserRead])
def users_list(
    db: Session = Depends(get_db),
    academy_id: UUID | None = Query(None, description="Filtrar por academia (colegas da academia)"),
    current_user: User = Depends(get_current_user),
):
    """Lista usuários. Admin: opcional academy_id. Professor/gerente: própria academia. Aluno/outros: só se academy_id for o da própria academia (colegas)."""
    if current_user.role == "administrador":
        return list_users(db, academy_id=academy_id)
    if current_user.role in ("gerente_academia", "professor"):
        if current_user.academy_id is None:
            return []
        return list_users(db, academy_id=current_user.academy_id)
    # Aluno, supervisor ou outro: só pode listar colegas da própria academia
    if current_user.academy_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Você não está vinculado a uma academia.",
        )
    if academy_id is None or academy_id != current_user.academy_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Você só pode listar usuários da sua academia.",
        )
    return list_users(db, academy_id=current_user.academy_id)


@router.get("/{user_id}", response_model=UserRead)
def user_get(
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Obtém um usuário por ID. Professor/gerente só acessa usuários da própria academia."""
    user = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    if current_user.role != "administrador" and user.academy_id != current_user.academy_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso negado. Você só pode acessar usuários da sua academia.")
    return user


@router.get("/{user_id}/points")
def user_points(user_id: UUID, db: Session = Depends(get_db)):
    """Total de pontos do usuário (execuções confirmadas)."""
    user = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return {"user_id": user_id, "points": total_points_for_user(db, user_id)}


@router.get("/{user_id}/points_log")
def user_points_log(
    user_id: UUID,
    db: Session = Depends(get_db),
    limit: int = Query(100, ge=1, le=500),
):
    """Histórico de pontuação do usuário (execuções confirmadas e conclusões de missão)."""
    user = get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return {"user_id": user_id, "entries": get_points_log(db, user_id, limit=limit)}


@router.post("", response_model=UserRead, status_code=201)
def user_create(
    body: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Cria um usuário (email único). Admin escolhe academia; professor/gerente vincula à própria."""
    existing = get_user_by_email(db, body.email)
    if existing:
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")
    if current_user.role == "administrador":
        academy_id = body.academy_id
    else:
        if current_user.academy_id is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Você precisa estar vinculado a uma academia para cadastrar usuários.",
            )
        academy_id = current_user.academy_id
    return create_user(
        db,
        email=body.email.strip().lower(),
        name=body.name,
        graduation=body.graduation,
        role=body.role,
        academy_id=academy_id,
        password=body.password,
    )


@router.patch("/{user_id}", response_model=UserRead)
def user_update(
    user_id: UUID,
    body: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Atualiza um usuário. Professor/gerente só edita usuários da própria academia e não pode alterar academy_id."""
    target = get_user(db, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    if current_user.role != "administrador":
        if target.academy_id != current_user.academy_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso negado. Você só pode editar usuários da sua academia.")
    payload = body.model_dump(exclude_unset=True)
    if current_user.role != "administrador":
        payload.pop("academy_id", None)
    updated = update_user(
        db,
        user_id,
        name=payload.get("name"),
        graduation=payload.get("graduation"),
        role=payload.get("role"),
        academy_id=payload.get("academy_id"),
        points_adjustment=payload.get("points_adjustment"),
        password=payload.get("password"),
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return updated


@router.delete("/{user_id}", status_code=204)
def user_delete(
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_academy_access),
):
    """Exclui o usuário. Professor/gerente só pode excluir usuários da própria academia."""
    target = get_user(db, user_id)
    if not target:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    if current_user.role != "administrador" and target.academy_id != current_user.academy_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso negado. Você só pode excluir usuários da sua academia.")
    try:
        if not delete_user(db, user_id):
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return None
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao excluir usuário: {e!s}",
        )
