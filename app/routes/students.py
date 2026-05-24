"""Lista compacta de alunos por academia (chamada manual)."""

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.list_pagination import MAX_LIST_LIMIT
from app.core.role_deps import require_write_access, verify_academy_access
from app.database import get_db
from app.models import User
from app.schemas.students import AcademyStudentListItem

router = APIRouter()


@router.get("/academy/{academy_id}/list", response_model=list[AcademyStudentListItem])
async def academy_students_list(
    academy_id: UUID,
    offset: int = Query(0, ge=0, description="Offset para paginação"),
    limit: int = Query(50, ge=1, le=MAX_LIST_LIMIT, description="Limite de resultados (máximo 50)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_write_access),
):
    """Todos os alunos activos (não congelados) da academia, ordenados por nome."""
    verify_academy_access(current_user, str(academy_id))

    sort_key = func.lower(func.coalesce(User.name, User.email))
    stmt = (
        select(User)
        .where(User.academy_id == academy_id)
        .where(User.role == "aluno")
        .where(User.account_frozen.is_(False))
        .order_by(sort_key.asc())
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [
        AcademyStudentListItem(
            id=u.id,
            name=u.name,
            belt=u.graduation,
            avatar_url=u.avatar_url,
        )
        for u in rows
    ]
