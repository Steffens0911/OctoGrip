from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class NotificationRead(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    body: str
    read: bool
    data: dict[str, Any] | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AnnouncementCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    body: str = Field(..., min_length=1)
