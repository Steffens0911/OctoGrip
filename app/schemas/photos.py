"""Schemas Pydantic para OctoPhotos."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class PhotoAuthor(BaseModel):
    id: uuid.UUID
    name: str | None
    avatar_url: str | None = None

    model_config = {"from_attributes": True}


class PhotoRead(BaseModel):
    id: uuid.UUID
    academy_id: uuid.UUID
    author: PhotoAuthor
    image_url: str | None
    thumbnail_url: str | None
    caption: str | None
    status: str
    likes_count: int
    comments_count: int = 0
    liked_by_me: bool = False
    is_system_post: bool
    system_post_type: str | None
    system_post_ref_id: uuid.UUID | None
    created_at: datetime

    model_config = {"from_attributes": True}


class PhotoFeedPage(BaseModel):
    items: list[PhotoRead]
    next_cursor: str | None


class PhotoCreate(BaseModel):
    caption: str | None = Field(None, max_length=280)


class CommentAuthor(BaseModel):
    id: uuid.UUID
    name: str | None
    avatar_url: str | None = None

    model_config = {"from_attributes": True}


class CommentRead(BaseModel):
    id: uuid.UUID
    photo_id: uuid.UUID
    author: CommentAuthor
    body: str
    created_at: datetime

    model_config = {"from_attributes": True}


class CommentCreate(BaseModel):
    body: str = Field(..., min_length=1, max_length=500)


class RestrictionRead(BaseModel):
    id: uuid.UUID
    academy_id: uuid.UUID
    user_id: uuid.UUID
    user_name: str | None = None
    reason: str | None
    expires_at: datetime | None
    active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class RestrictionCreate(BaseModel):
    user_id: uuid.UUID
    reason: str | None = Field(None, max_length=500)
    expires_at: datetime | None = None


class RestrictionPatch(BaseModel):
    active: bool | None = None
    reason: str | None = Field(None, max_length=500)
    expires_at: datetime | None = None


class MentionSuggestion(BaseModel):
    id: uuid.UUID
    name: str
    avatar_url: str | None = None

    model_config = {"from_attributes": True}
