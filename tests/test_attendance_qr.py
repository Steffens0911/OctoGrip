"""Chamada por QR: criação de sessão e registro de presença."""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.config import settings


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _sig(msg: str) -> str:
    mac = hmac.new(settings.ATTENDANCE_QR_SECRET.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).digest()
    return _b64url(mac)


@pytest.mark.asyncio
async def test_professor_cria_sessao_qr_aluno_registra_presenca(client, professor_headers, aluno_headers):
    r = await client.post("/attendance/sessions", headers=professor_headers, json={"title": "Treino 19h"})
    assert r.status_code == 201, r.text
    session_id = r.json()["id"]

    qr = await client.get(f"/attendance/sessions/{session_id}/qr?ttl_seconds=60", headers=professor_headers)
    assert qr.status_code == 200, qr.text
    payload = qr.json()["payload"]

    scan = await client.post("/attendance/scan", headers=aluno_headers, json={"payload": payload})
    assert scan.status_code == 201, scan.text
    data = scan.json()
    assert data["session_id"] == session_id
    assert data["method"] == "qr"

    records = await client.get(f"/attendance/sessions/{session_id}/records", headers=professor_headers)
    assert records.status_code == 200, records.text
    assert len(records.json()) == 1


@pytest.mark.asyncio
async def test_scan_dedupe(client, professor_headers, aluno_headers):
    r = await client.post("/attendance/sessions", headers=professor_headers, json={})
    session_id = r.json()["id"]
    qr = await client.get(f"/attendance/sessions/{session_id}/qr?ttl_seconds=60", headers=professor_headers)
    payload = qr.json()["payload"]

    s1 = await client.post("/attendance/scan", headers=aluno_headers, json={"payload": payload})
    assert s1.status_code == 201
    s2 = await client.post("/attendance/scan", headers=aluno_headers, json={"payload": payload})
    assert s2.status_code == 201
    assert s1.json()["id"] == s2.json()["id"]

    records = await client.get(f"/attendance/sessions/{session_id}/records", headers=professor_headers)
    assert records.status_code == 200
    assert len(records.json()) == 1


@pytest.mark.asyncio
async def test_scan_token_expirado(client, professor_headers, aluno_headers):
    r = await client.post("/attendance/sessions", headers=professor_headers, json={})
    session_id = r.json()["id"]

    # Payload com exp no passado, mas assinatura válida
    now = int(datetime.now(timezone.utc).timestamp())
    iat = now - 120
    exp = now - 1
    nonce = secrets.token_urlsafe(10)
    msg = f"{session_id}|{iat}|{exp}|{nonce}"
    payload = f"sid={session_id}&iat={iat}&exp={exp}&nonce={nonce}&sig={_sig(msg)}"

    scan = await client.post("/attendance/scan", headers=aluno_headers, json={"payload": payload})
    assert scan.status_code == 400


@pytest.mark.asyncio
async def test_scan_sessao_fechada(client, professor_headers, aluno_headers):
    r = await client.post("/attendance/sessions", headers=professor_headers, json={})
    session_id = r.json()["id"]
    qr = await client.get(f"/attendance/sessions/{session_id}/qr?ttl_seconds=60", headers=professor_headers)
    payload = qr.json()["payload"]

    close = await client.post(f"/attendance/sessions/{session_id}/close", headers=professor_headers)
    assert close.status_code == 200

    scan = await client.post("/attendance/scan", headers=aluno_headers, json={"payload": payload})
    assert scan.status_code == 409


@pytest.mark.asyncio
async def test_scan_cross_academy_forbidden(client, db, professor_user, professor_headers, aluno_headers):
    from app.models import Academy, User
    from app.core.security import hash_password_sync

    # sessão na academia do professor_user
    r = await client.post("/attendance/sessions", headers=professor_headers, json={})
    session_id = r.json()["id"]
    qr = await client.get(f"/attendance/sessions/{session_id}/qr?ttl_seconds=60", headers=professor_headers)
    payload = qr.json()["payload"]

    other_academy = Academy(name=f"Academia {uuid4().hex[:6]}", slug=f"acad-{uuid4().hex[:6]}")
    db.add(other_academy)
    await db.commit()
    await db.refresh(other_academy)

    other_student = User(
        email=f"aluno2-{uuid4().hex[:8]}@test.com",
        name="Aluno 2",
        role="aluno",
        graduation="white",
        academy_id=other_academy.id,
        password_hash=hash_password_sync("aluno123"),
    )
    db.add(other_student)
    await db.commit()
    await db.refresh(other_student)

    # gera token do outro aluno
    from app.core.security import create_access_token

    headers = {"Authorization": f"Bearer {create_access_token(other_student.id)}"}
    scan = await client.post("/attendance/scan", headers=headers, json={"payload": payload})
    assert scan.status_code == 403

