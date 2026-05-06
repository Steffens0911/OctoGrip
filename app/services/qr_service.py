"""Serviço de tokens QR para chamada de presença.

Formato do token: <header_b64>.<payload_b64>.<assinatura_b64>
  header  : {"alg":"HS256","typ":"ATTP"}
  payload : {"sid":"<uuid>","iat":<unix>,"exp":<unix>,"jti":"<nonce>"}
  assinatura: HMAC-SHA256(secret, "<header_b64>.<payload_b64>")
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import threading
from datetime import datetime, timedelta, timezone
from uuid import UUID

from app.config import settings
from app.core.exceptions import AttendanceQrInvalidError

# Alfabeto sem caracteres ambíguos (0/O, 1/I/L)
_ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
_short_codes: dict[str, tuple[UUID, int]] = {}  # code -> (session_id, exp_unix)
_short_lock = threading.Lock()


def _cleanup_expired() -> None:
    now = int(datetime.now(timezone.utc).timestamp())
    expired = [k for k, (_, exp) in _short_codes.items() if exp <= now]
    for k in expired:
        _short_codes.pop(k, None)


def issue_short(session_id: UUID, exp_unix: int) -> str:
    """Gera um código de 5 caracteres mapeado para session_id com o mesmo TTL do QR."""
    with _short_lock:
        _cleanup_expired()
        for _ in range(30):
            code = "".join(secrets.choice(_ALPHA) for _ in range(5))
            if code not in _short_codes:
                _short_codes[code] = (session_id, exp_unix)
                return code
        code = "".join(secrets.choice(_ALPHA) for _ in range(5))
        _short_codes[code] = (session_id, exp_unix)
        return code


def verify_short(code: str) -> UUID:
    """Valida código curto e retorna session_id. Lança AttendanceQrInvalidError se inválido."""
    now = int(datetime.now(timezone.utc).timestamp())
    with _short_lock:
        entry = _short_codes.get(code.upper())
    if entry is None:
        raise AttendanceQrInvalidError()
    session_id, exp = entry
    if exp <= now:
        raise AttendanceQrInvalidError()
    return session_id


_HEADER_B64 = base64.urlsafe_b64encode(
    json.dumps({"alg": "HS256", "typ": "ATTP"}, separators=(",", ":")).encode()
).rstrip(b"=").decode()


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _b64url_decode(s: str) -> bytes:
    padding = 4 - len(s) % 4
    return base64.urlsafe_b64decode(s + "=" * (padding % 4))


def _sign(secret: str, message: str) -> str:
    mac = hmac.new(secret.encode(), message.encode(), hashlib.sha256).digest()
    return _b64url_encode(mac)


def issue(session_id: UUID, ttl_seconds: int = 60) -> tuple[str, datetime]:
    """Gera um token QR assinado. Retorna (token, expires_at)."""
    now = datetime.now(timezone.utc)
    exp = now + timedelta(seconds=max(15, min(ttl_seconds, 180)))
    payload_b64 = _b64url_encode(
        json.dumps(
            {
                "sid": str(session_id),
                "iat": int(now.timestamp()),
                "exp": int(exp.timestamp()),
                "jti": secrets.token_urlsafe(12),
            },
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{_HEADER_B64}.{payload_b64}"
    token = f"{signing_input}.{_sign(settings.QR_SECRET, signing_input)}"
    return token, exp


def verify(token: str) -> UUID:
    """Valida o token e retorna o session_id. Lança AttendanceQrInvalidError em qualquer problema."""
    try:
        header_b64, payload_b64, sig = token.split(".")
    except ValueError:
        raise AttendanceQrInvalidError()

    if header_b64 != _HEADER_B64:
        raise AttendanceQrInvalidError()

    signing_input = f"{header_b64}.{payload_b64}"
    expected_sig = _sign(settings.QR_SECRET, signing_input)
    if not hmac.compare_digest(expected_sig, sig):
        raise AttendanceQrInvalidError()

    try:
        data = json.loads(_b64url_decode(payload_b64))
        session_id = UUID(data["sid"])
        exp_i: int = int(data["exp"])
        iat_i: int = int(data["iat"])
    except Exception:
        raise AttendanceQrInvalidError()

    now = int(datetime.now(timezone.utc).timestamp())
    if exp_i <= now:
        raise AttendanceQrInvalidError()
    if exp_i - iat_i > 600:
        raise AttendanceQrInvalidError()

    return session_id
