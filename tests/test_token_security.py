"""JWT: validade, impressão da senha (pwv) e tokens antigos sem validade."""

from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

from jose import jwt

from app.config import settings
from app.core import security
from app.core.security import (
    create_access_token,
    decode_access_token,
    generate_csrf_token,
    token_matches_password,
)


def _user(password_hash: str | None = "hash-atual"):
    return SimpleNamespace(id=uuid4(), password_hash=password_hash)


def _encode(payload: dict) -> str:
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def test_token_novo_tem_validade_e_impressao_da_senha():
    user = _user()
    payload = decode_access_token(create_access_token(user))
    assert payload["sub"] == str(user.id)
    lifetime = payload["exp"] - payload["iat"]
    assert lifetime == settings.JWT_EXPIRE_MINUTES * 60
    assert token_matches_password(payload, "hash-atual")


def test_impressao_nao_expoe_o_hash():
    payload = decode_access_token(create_access_token(_user("hash-atual")))
    assert "hash-atual" not in payload["pwv"]


def test_trocar_a_senha_invalida_o_token():
    payload = decode_access_token(create_access_token(_user("hash-antigo")))
    assert not token_matches_password(payload, "hash-novo")


def test_conta_anonimizada_sem_senha_invalida_o_token():
    payload = decode_access_token(create_access_token(_user("hash-atual")))
    assert not token_matches_password(payload, None)


def test_token_vencido_e_recusado():
    past = datetime.now(UTC) - timedelta(days=1)
    token = _encode({"sub": str(uuid4()), "iat": past - timedelta(days=30), "exp": past, "pwv": "x"})
    assert decode_access_token(token) is None


def test_token_de_csrf_nao_vale_como_login():
    assert decode_access_token(generate_csrf_token(uuid4())) is None


def test_token_assinado_com_outro_segredo_e_recusado():
    token = jwt.encode({"sub": str(uuid4())}, "outro-segredo-qualquer-com-32-chars!!", algorithm="HS256")
    assert decode_access_token(token) is None


def test_token_antigo_vale_ate_a_data_de_corte(monkeypatch):
    payload = decode_access_token(_encode({"sub": str(uuid4())}))
    monkeypatch.setattr(settings, "JWT_LEGACY_TOKENS_UNTIL", date(2026, 12, 31))
    monkeypatch.setattr(security, "today_in_app_tz", lambda: date(2026, 12, 31))
    assert token_matches_password(payload, "qualquer")
    monkeypatch.setattr(security, "today_in_app_tz", lambda: date(2027, 1, 1))
    assert not token_matches_password(payload, "qualquer")


def test_token_antigo_recusado_sem_data_de_corte(monkeypatch):
    payload = decode_access_token(_encode({"sub": str(uuid4())}))
    monkeypatch.setattr(settings, "JWT_LEGACY_TOKENS_UNTIL", None)
    assert not token_matches_password(payload, "qualquer")
