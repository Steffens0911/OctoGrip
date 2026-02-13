from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.mission import MissionTodayResponse
from app.services.mission_service import get_mission_today_response

router = APIRouter()


@router.get("", response_model=MissionTodayResponse)
def mission_today(
    db: Session = Depends(get_db),
    level: str = "beginner",
    user_id: UUID | None = None,
    review_after_days: int = 7,
    academy_id: UUID | None = None,
):
    """
    Retorna a missão do dia por nível (beginner/intermediate).
    A-02: academy_id (ou do user) usa missão da academia; senão, missão global.
    PF-03/PF-04: user_id prioriza revisão e posição difícil.
    """
    payload = get_mission_today_response(
        db,
        level=level,
        user_id=user_id,
        review_after_days=review_after_days,
        academy_id=academy_id,
    )
    if not payload:
        raise HTTPException(status_code=404, detail="Nenhuma missão disponível no momento.")
    return payload
