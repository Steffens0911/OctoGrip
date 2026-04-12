"""
Agregação de todos os routers da API.
Centraliza prefixos e tags; main.py só inclui este router.
"""
from fastapi import APIRouter

from app.routes import (
    academies,
    admin,
    admin_audit,
    admin_backup,
    auth,
    executions,
    health,
    lesson_complete,
    lessons,
    me_push,
    me_training_videos,
    metrics,
    mission,
    mission_complete,
    mission_usages,
    missions,
    partners,
    professors,
    reports,
    techniques,
    training_feedback,
    training_videos,
    trophies,
    users,
)

api_router = APIRouter()

api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(admin_backup.router, prefix="/admin", tags=["admin-backup"])
api_router.include_router(admin_audit.router, prefix="/admin", tags=["admin-audit"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(academies.router, prefix="/academies", tags=["academies"])
api_router.include_router(professors.router, prefix="/professors", tags=["professors"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(lessons.router, prefix="/lessons", tags=["lessons"])
api_router.include_router(techniques.router, prefix="/techniques", tags=["techniques"])
api_router.include_router(partners.router, prefix="/partners", tags=["partners"])
api_router.include_router(missions.router, prefix="/missions", tags=["missions"])
api_router.include_router(mission.router, prefix="/mission_today", tags=["mission"])
api_router.include_router(mission_complete.router, prefix="/mission_complete", tags=["mission_complete"])
api_router.include_router(mission_usages.router, prefix="/mission_usages", tags=["mission_usages"])
api_router.include_router(executions.router, prefix="/executions", tags=["executions"])
api_router.include_router(trophies.router, prefix="/trophies", tags=["trophies"])
api_router.include_router(lesson_complete.router, prefix="/lesson_complete", tags=["lesson_complete"])
api_router.include_router(training_feedback.router, prefix="/training_feedback", tags=["training_feedback"])
api_router.include_router(metrics.router, prefix="/metrics", tags=["metrics"])
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])
api_router.include_router(training_videos.router, prefix="/training_videos", tags=["training_videos"])
api_router.include_router(me_training_videos.router, prefix="/me", tags=["me"])
api_router.include_router(me_push.router, prefix="/me", tags=["me"])
