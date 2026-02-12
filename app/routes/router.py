"""
Agregação de todos os routers da API.
Centraliza prefixos e tags; main.py só inclui este router.
"""
from fastapi import APIRouter

from app.routes import health, lesson_complete, lessons, metrics, mission, training_feedback

api_router = APIRouter()

api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(lessons.router, prefix="/lessons", tags=["lessons"])
api_router.include_router(mission.router, prefix="/mission_today", tags=["mission"])
api_router.include_router(lesson_complete.router, prefix="/lesson_complete", tags=["lesson_complete"])
api_router.include_router(training_feedback.router, prefix="/training_feedback", tags=["training_feedback"])
api_router.include_router(metrics.router, prefix="/metrics", tags=["metrics"])
