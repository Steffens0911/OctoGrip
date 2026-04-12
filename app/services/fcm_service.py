"""Envio de notificações via Firebase Cloud Messaging HTTP v1."""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path

import httpx
from google.auth.transport.requests import Request
from google.oauth2 import service_account

logger = logging.getLogger(__name__)

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


def _access_token_from_service_account(path: str) -> str:
    p = Path(path)
    if not p.is_file():
        raise FileNotFoundError(f"Ficheiro de service account não encontrado: {path}")
    creds = service_account.Credentials.from_service_account_file(
        str(p),
        scopes=[_FCM_SCOPE],
    )
    creds.refresh(Request())
    if not creds.token:
        raise RuntimeError("Falha ao obter access token OAuth2 para FCM.")
    return creds.token


async def send_fcm_data_message(
    *,
    project_id: str,
    service_account_path: str,
    device_token: str,
    title: str,
    body: str,
) -> tuple[bool, bool]:
    """
    Envia uma notificação de sistema (barra de notificações).

    Returns:
        (success, should_drop_token) — should_drop_token=True se o token for inválido.
    """
    access_token = await asyncio.to_thread(_access_token_from_service_account, service_account_path)
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    payload = {
        "message": {
            "token": device_token,
            "notification": {"title": title, "body": body},
            "android": {"priority": "HIGH"},
        }
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.post(
            url,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json; charset=UTF-8",
            },
            content=json.dumps(payload),
        )
    text = r.text or ""
    if r.status_code == 200:
        return True, False
    # Token expirado ou app desinstalada
    if r.status_code == 404 and ("NOT_FOUND" in text or "Requested entity was not found" in text):
        return False, True
    if r.status_code == 400 and ("UNREGISTERED" in text or "not a valid FCM registration token" in text):
        return False, True
    logger.warning(
        "FCM: envio falhou",
        extra={"status_code": r.status_code, "snippet": text[:400]},
    )
    return False, False
