"""Broadcast WebSocket para sessões de presença (QR).

Conexões são mantidas **em memória no processo atual**. O projeto já usa
padrões similares (ex.: lockout de login em memória). Para escalar com
múltiplos workers Uvicorn, substituir por Redis pub/sub ou canal compartilhado.
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any
from uuid import UUID

from starlette.websockets import WebSocket

logger = logging.getLogger(__name__)


class AttendanceConnectionManager:
    """Agrupa WebSockets por `session_id` e envia eventos JSON (texto)."""

    def __init__(self) -> None:
        self._conns: dict[str, set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, session_id: UUID, ws: WebSocket) -> None:
        key = str(session_id)
        async with self._lock:
            self._conns.setdefault(key, set()).add(ws)
        n = len(self._conns.get(key, set()))
        logger.debug("attendance_ws connect session=%s listeners=%s", key, n)

    async def disconnect(self, session_id: UUID, ws: WebSocket) -> None:
        key = str(session_id)
        async with self._lock:
            bucket = self._conns.get(key)
            if bucket:
                bucket.discard(ws)
                if not bucket:
                    self._conns.pop(key, None)

    async def broadcast(self, session_id: UUID, event: dict[str, Any]) -> None:
        key = str(session_id)
        async with self._lock:
            listeners = list(self._conns.get(key, set()))
        if not listeners:
            return
        payload = json.dumps(event, default=str)
        dead: list[WebSocket] = []
        for ws in listeners:
            try:
                await ws.send_text(payload)
            except Exception as exc:  # noqa: BLE001 — desconexão abrupta é comum
                logger.debug("attendance_ws send failed session=%s: %s", key, exc)
                dead.append(ws)
        if not dead:
            return
        async with self._lock:
            bucket = self._conns.get(key)
            if bucket:
                for ws in dead:
                    bucket.discard(ws)
                if not bucket:
                    self._conns.pop(key, None)


attendance_manager = AttendanceConnectionManager()
