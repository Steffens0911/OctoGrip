"""Models SQLAlchemy — importar todos para registro no Base (Alembic/create_all)."""

from app.database import Base
from app.models.academy import Academy
from app.models.academy_marketplace_item import AcademyMarketplaceItem
from app.models.academy_photo import AcademyPhoto, AcademyPhotoLike, AcademyPhotoRestriction
from app.models.attendance_record import AttendanceRecord
from app.models.attendance_session import AttendanceSession
from app.models.audit_log import AuditLog
from app.models.base import UUIDMixin
from app.models.collective_goal import CollectiveGoal
from app.models.enrollment_invite import EnrollmentInvite, PendingEnrollment
from app.models.face_recognition_job import FaceRecognitionJob
from app.models.global_partner import GlobalPartner
from app.models.lesson import Lesson
from app.models.lesson_progress import LessonProgress
from app.models.manual_trophy import AcademyChampionshipEvent, AcademyTrophyAward, AcademyTrophyTemplate
from app.models.mission import Mission
from app.models.mission_usage import MissionUsage
from app.models.notification import Notification
from app.models.partner import Partner
from app.models.password_reset_token import PasswordResetToken
from app.models.professor import Professor
from app.models.soft_delete import SoftDeleteMixin
from app.models.student_face_embedding import StudentFaceEmbedding
from app.models.technique import Technique
from app.models.technique_execution import TechniqueExecution
from app.models.training_feedback import TrainingFeedback
from app.models.training_video import TrainingVideo, TrainingVideoDailyView
from app.models.trophy import Trophy
from app.models.user import User
from app.models.user_device_token import UserDeviceToken
from app.models.user_login_day import UserLoginDay
from app.models.user_trophy_earned import UserTrophyEarned
from app.models.weekly_technique_kit import UserWeeklyKitChoice, WeeklyKitItem, WeeklyTechniqueKit

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
    "GlobalPartner",
    "TrainingVideo",
    "TrainingVideoDailyView",
    "AcademyMarketplaceItem",
    "UserDeviceToken",
    "WeeklyTechniqueKit",
    "WeeklyKitItem",
    "UserWeeklyKitChoice",
    "AttendanceSession",
    "AttendanceRecord",
    "StudentFaceEmbedding",
    "FaceRecognitionJob",
    "UserTrophyEarned",
    "Notification",
    "AcademyPhoto",
    "AcademyPhotoLike",
    "AcademyPhotoRestriction",
    "AcademyTrophyTemplate",
    "AcademyChampionshipEvent",
    "AcademyTrophyAward",
    "EnrollmentInvite",
    "PendingEnrollment",
    "PasswordResetToken",
]
