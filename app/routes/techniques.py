"""CRUD de técnicas (listagem por academia)."""
from uuid import UUID

import traceback
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError, ConflictError, ForbiddenError, TechniqueNotFoundError
from app.core.role_deps import require_read_access, require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.technique import TechniqueCreate, TechniqueRead, TechniqueUpdate
from app.services.technique_service import (
    create_technique,
    delete_technique,
    get_technique,
    list_techniques,
    update_technique,
)

router = APIRouter()


def _resolve_academy_id(current_user: User, academy_id: UUID | None) -> UUID:
    """Resolve academy_id: admin exige explícito, demais usam sua própria."""
    if academy_id is not None:
        verify_academy_access(current_user, str(academy_id))
        return academy_id
    if current_user.role != "administrador":
        if current_user.academy_id is None:
            raise ForbiddenError("Você precisa estar vinculado a uma academia.")
        return current_user.academy_id
    raise AppError("academy_id é obrigatório para listar técnicas.")


@router.get("", response_model=list[TechniqueRead])
async def techniques_list(
    academy_id: UUID | None = Query(None, description="Filtra por academia"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Lista técnicas por academia."""
    try:
        resolved = _resolve_academy_id(current_user, academy_id)
        return await list_techniques(db, academy_id=resolved)
    except AppError:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{technique_id}", response_model=TechniqueRead)
async def technique_get(
    technique_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_read_access),
):
    """Retorna uma técnica por ID."""
    try:
        verify_academy_access(current_user, str(academy_id))
        technique = await get_technique(db, technique_id)
        if not technique or technique.academy_id != academy_id:
            raise TechniqueNotFoundError()
        return technique
    except TechniqueNotFoundError:
        raise
    except AppError:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("", response_model=TechniqueRead, status_code=201)
async def technique_create(
    body: TechniqueCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Cria uma nova técnica na academia."""
    try:
        verify_academy_access(current_user, str(body.academy_id) if body.academy_id else None)
        return await create_technique(
            db,
            academy_id=body.academy_id,
            name=body.name,
            slug=body.slug or None,
            description=body.description,
            video_url=body.video_url or None,
            base_points=body.base_points,
        )
    except AppError:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{technique_id}", response_model=TechniqueRead)
async def technique_update(
    technique_id: UUID,
    body: TechniqueUpdate,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Atualiza uma técnica."""
    try:
        verify_academy_access(current_user, str(academy_id))
        technique = await get_technique(db, technique_id)
        if not technique or technique.academy_id != academy_id:
            raise TechniqueNotFoundError()
        payload = body.model_dump(exclude_unset=True)
        updated = await update_technique(db, technique_id, **payload)
        if not updated:
            raise TechniqueNotFoundError()
        return updated
    except TechniqueNotFoundError:
        raise
    except AppError:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{technique_id}", status_code=204)
async def technique_delete(
    technique_id: UUID,
    academy_id: UUID = Query(..., description="Academia do contexto"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Remove uma técnica."""
    try:
        verify_academy_access(current_user, str(academy_id))
        technique = await get_technique(db, technique_id)
        if not technique or technique.academy_id != academy_id:
            raise TechniqueNotFoundError()
        try:
            if not await delete_technique(db, technique_id):
                raise TechniqueNotFoundError()
            return None
        except IntegrityError:
            await db.rollback()
            raise ConflictError("Não é possível excluir: existem lições ou missões vinculadas a esta técnica.")
    except TechniqueNotFoundError:
        raise
    except AppError:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
