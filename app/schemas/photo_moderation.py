"""Schemas de denúncia de conteúdo e bloqueio de usuários no feed de fotos."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

ReportReason = Literal["spam", "nudity", "violence", "harassment", "other"]
ResolveAction = Literal["dismiss", "remove"]


class ReportCreate(BaseModel):
    reason: ReportReason
    details: str | None = Field(None, max_length=500)


class ReportAck(BaseModel):
    id: uuid.UUID
    status: str
    already_reported: bool = False


class ReportRead(BaseModel):
    id: uuid.UUID
    status: str
    reason: str
    details: str | None
    created_at: datetime
    reporter_name: str | None = None
    photo_id: uuid.UUID
    comment_id: uuid.UUID | None = None
    target_type: Literal["photo", "comment"]
    target_author_id: uuid.UUID | None = None
    target_author_name: str | None = None
    target_text: str | None = None
    target_thumbnail_url: str | None = None
    target_removed: bool = False
    reports_on_target: int = 1


class ReportResolve(BaseModel):
    action: ResolveAction


class BlockedUserRead(BaseModel):
    user_id: uuid.UUID
    name: str | None
    avatar_url: str | None = None
    created_at: datetime
