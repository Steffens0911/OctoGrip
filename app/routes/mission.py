from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.auth_deps import get_current_user_optional
from app.models import User
from app.schemas.mission import MissionTodayResponse, MissionWeekResponse
from app.services.mission_service import get_mission_today_response, get_mission_week_response

router = APIRouter()


@router.get("/week", response_model=MissionWeekResponse)
def mission_week(
    db: Session = Depends(get_db),
    level: str = "beginner",
    user_id: UUID | None = None,
    academy_id: UUID | None = None,
    current_user: User | None = Depends(get_current_user_optional),
):
    """
    Retorna as 3 missões da semana (Missão 1, 2, 3). Se enviar Authorization Bearer, usa o usuário do token.
    """
    uid = current_user.id if current_user else user_id
    payload = get_mission_week_response(
        db, level=level, user_id=uid, academy_id=academy_id
    )
    return JSONResponse(
        content=payload.model_dump(mode="json"),
        headers={"Cache-Control": "no-store"},
    )


@router.get("", response_model=MissionTodayResponse)
def mission_today(
    db: Session = Depends(get_db),
    level: str = "beginner",
    user_id: UUID | None = None,
    review_after_days: int = 7,
    academy_id: UUID | None = None,
    current_user: User | None = Depends(get_current_user_optional),
):
    """
    Retorna a missão do dia por nível. Se enviar Authorization Bearer, usa o usuário do token para personalização.
    """
    uid = current_user.id if current_user else user_id
    payload = get_mission_today_response(
        db,
        level=level,
        user_id=uid,
        review_after_days=review_after_days,
        academy_id=academy_id,
    )
    if not payload:
        raise HTTPException(status_code=404, detail="Nenhuma missão disponível no momento.")
    return payload
