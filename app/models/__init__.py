"""Models SQLAlchemy — importar todos para registro no Base (Alembic/create_all)."""
from app.database import Base
from app.models.base import UUIDMixin
from app.models.user import User
from app.models.position import Position
from app.models.technique import Technique
from app.models.lesson import Lesson
from app.models.lesson_progress import LessonProgress
from app.models.training_feedback import TrainingFeedback
from app.models.mission import Mission

__all__ = [
    "Base",
    "UUIDMixin",
    "User",
    "Position",
    "Technique",
    "Lesson",
    "LessonProgress",
    "TrainingFeedback",
    "Mission",
]
