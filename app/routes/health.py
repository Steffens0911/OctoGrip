from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.database import get_db

router = APIRouter()


@router.get("")
def health():
    """Health check simples (sem banco)."""
    return {"status": "ok"}


@router.get("/db")
def health_db(db: Session = Depends(get_db)):
    """Health check com verificação de conexão ao PostgreSQL."""
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception as e:
        return {"status": "error", "database": str(e)}
