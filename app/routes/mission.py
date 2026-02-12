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
):
    """Retorna a missão do dia por nível (beginner/intermediate). Dados prontos para o frontend."""
    payload = get_mission_today_response(db, level=level)
    if not payload:
        raise HTTPException(status_code=404, detail="Nenhuma missão disponível no momento.")
    return payload
