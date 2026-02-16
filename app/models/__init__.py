"""Models SQLAlchemy — importar todos para registro no Base (Alembic/create_all)."""
from app.database import Base
from app.models.base import UUIDMixin
from app.models.academy import Academy
from app.models.professor import Professor
from app.models.user import User
from app.models.position import Position
from app.models.technique import Technique
from app.models.lesson import Lesson
from app.models.lesson_progress import LessonProgress
from app.models.training_feedback import TrainingFeedback
from app.models.mission import Mission
from app.models.mission_usage import MissionUsage
from app.models.technique_execution import TechniqueExecution
from app.models.collective_goal import CollectiveGoal

__all__ = [
    "Base",
    "UUIDMixin",
    "Academy",
    "Professor",
    "User",
    "Position",
    "Technique",
    "Lesson",
    "LessonProgress",
    "TrainingFeedback",
    "Mission",
    "MissionUsage",
    "TechniqueExecution",
    "CollectiveGoal",
]
