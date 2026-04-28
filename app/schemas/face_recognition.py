from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class FaceRecognitionSubmitResponse(BaseModel):
    job_id: UUID
    status: Literal["pending"]
    message: str


class FaceRecognitionStudentRead(BaseModel):
    id: UUID
    name: str | None = None
    avatar_url: str | None = None
    belt: str | None = None


class FaceRecognitionResultRead(BaseModel):
    face_index: int
    face_crop_base64: str
    status: Literal["auto_identified", "suggestion", "unknown"]
    confidence: float
    student: FaceRecognitionStudentRead | None = None


class FaceRecognitionJobStatusRead(BaseModel):
    job_id: UUID
    status: Literal["pending", "processing", "completed", "failed"]
    session_id: UUID
    total_faces_detected: int | None = None
    results: list[FaceRecognitionResultRead] | None = None
    error_message: str | None = None


class FaceRecognitionConfirmRequest(BaseModel):
    session_id: UUID
    job_id: UUID
    confirmed_student_ids: list[UUID] = Field(default_factory=list)


class FaceRecognitionConfirmResponse(BaseModel):
    session_id: UUID
    job_id: UUID
    created_records: int
    records: list[dict]


class FaceRecognitionEmbeddingStatusStudentRead(BaseModel):
    student_id: UUID
    name: str | None = None
    email: str
    avatar_url: str | None = None
    has_embedding: bool
    updated_at: datetime | None = None


class FaceRecognitionEmbeddingStatusRead(BaseModel):
    academy_id: UUID
    total_students: int
    with_embedding: int
    without_embedding: int
    students: list[FaceRecognitionEmbeddingStatusStudentRead]
