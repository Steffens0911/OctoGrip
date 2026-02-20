"""CRUD de usuários (painel desenvolvedores)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.services.user_service import create_user, delete_user, get_user, get_user_by_email, list_users, update_user
from app.services.execution_service import get_points_log, total_points_for_user

router = APIRouter()


@router.get("", response_model=list[UserRead])
async def users_list(
    db: AsyncSession = Depends(get_db),
    academy_id: UUID | None = Query(None, description="Filtrar por academia (colegas da academia)"),
):
    """Lista usuários. Opcionalmente filtra por academy_id."""
    return await list_users(db, academy_id=academy_id)


@router.get("/{user_id}", response_model=UserRead)
async def user_get(user_id: UUID, db: AsyncSession = Depends(get_db)):
    user = await get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return user


@router.get("/{user_id}/points")
async def user_points(user_id: UUID, db: AsyncSession = Depends(get_db)):
    """Total de pontos do usuário (execuções confirmadas)."""
    user = await get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return {"user_id": user_id, "points": await total_points_for_user(db, user_id)}


@router.get("/{user_id}/points_log")
async def user_points_log(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    limit: int = Query(100, ge=1, le=500),
):
    """Histórico de pontuação do usuário (execuções confirmadas e conclusões de missão)."""
    user = await get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return {"user_id": user_id, "entries": await get_points_log(db, user_id, limit=limit)}


@router.post("", response_model=UserRead, status_code=201)
async def user_create(body: UserCreate, db: AsyncSession = Depends(get_db)):
    """Cria um usuário (email único)."""
    existing = await get_user_by_email(db, body.email)
    if existing:
        raise HTTPException(status_code=409, detail="E-mail já cadastrado.")
    return await create_user(
        db,
        email=body.email,
        name=body.name,
        graduation=body.graduation,
        academy_id=body.academy_id,
    )


@router.patch("/{user_id}", response_model=UserRead)
async def user_update(user_id: UUID, body: UserUpdate, db: AsyncSession = Depends(get_db)):
    payload = body.model_dump(exclude_unset=True)
    updated = await update_user(
        db,
        user_id,
        name=payload.get("name"),
        graduation=payload.get("graduation"),
        academy_id=payload.get("academy_id"),
        points_adjustment=payload.get("points_adjustment"),
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return updated


@router.delete("/{user_id}", status_code=204)
async def user_delete(user_id: UUID, db: AsyncSession = Depends(get_db)):
    """Exclui o usuário e, em cascata, progressos, usos de missão e feedbacks."""
    try:
        if not await delete_user(db, user_id):
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return None
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao excluir usuário: {e!s}",
        )
