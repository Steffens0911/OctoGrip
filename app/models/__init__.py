"""Models SQLAlchemy — importar todos para registro no Base (Alembic/create_all)."""
from app.database import Base
from app.models.audit_log import AuditLog
from app.models.base import UUIDMixin
from app.models.soft_delete import SoftDeleteMixin
from app.models.academy import Academy
from app.models.professor import Professor
from app.models.user import User
from app.models.user_login_day import UserLoginDay
from app.models.technique import Technique
from app.models.lesson import Lesson
from app.models.lesson_progress import LessonProgress
from app.models.training_feedback import TrainingFeedback
from app.models.mission import Mission
from app.models.mission_usage import MissionUsage
from app.models.technique_execution import TechniqueExecution
from app.models.collective_goal import CollectiveGoal
from app.models.trophy import Trophy
from app.models.partner import Partner
from app.models.training_video import TrainingVideo, TrainingVideoDailyView
from app.models.user_device_token import UserDeviceToken

__all__ = [
    "Base",
    "UUIDMixin",
    "SoftDeleteMixin",
    "AuditLog",
    "Academy",
    "Professor",
    "User",
    "UserLoginDay",
    "Technique",
    "Lesson",
    "LessonProgress",
    "TrainingFeedback",
    "Mission",
    "MissionUsage",
    "TechniqueExecution",
    "CollectiveGoal",
    "Trophy",
    "Partner",
    "TrainingVideo",
    "TrainingVideoDailyView",
    "UserDeviceToken",
]
