"""
Agregação de todos os routers da API.
Centraliza prefixos e tags; main.py só inclui este router.
"""
from fastapi import APIRouter

from app.routes import academies, admin, health, lesson_complete, lessons, metrics, mission, mission_usages, missions, positions, professors, techniques, training_feedback, users

api_router = APIRouter()

api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(academies.router, prefix="/academies", tags=["academies"])
api_router.include_router(professors.router, prefix="/professors", tags=["professors"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(lessons.router, prefix="/lessons", tags=["lessons"])
api_router.include_router(techniques.router, prefix="/techniques", tags=["techniques"])
api_router.include_router(positions.router, prefix="/positions", tags=["positions"])
api_router.include_router(missions.router, prefix="/missions", tags=["missions"])
api_router.include_router(mission.router, prefix="/mission_today", tags=["mission"])
api_router.include_router(mission_usages.router, prefix="/mission_usages", tags=["mission_usages"])
api_router.include_router(lesson_complete.router, prefix="/lesson_complete", tags=["lesson_complete"])
api_router.include_router(training_feedback.router, prefix="/training_feedback", tags=["training_feedback"])
api_router.include_router(metrics.router, prefix="/metrics", tags=["metrics"])
