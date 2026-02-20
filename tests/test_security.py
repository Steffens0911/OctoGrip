"""Testes dos utilitários de segurança (hash, JWT)."""
import pytest
from uuid import uuid4

from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)


def test_hash_and_verify_password():
    plain = "minha-senha-123"
    hashed = hash_password(plain)
    assert hashed != plain
    assert verify_password(plain, hashed)


def test_verify_wrong_password():
    hashed = hash_password("correta")
    assert not verify_password("errada", hashed)


def test_create_and_decode_token():
    user_id = uuid4()
    token = create_access_token(user_id)
    decoded = decode_access_token(token)
    assert decoded == str(user_id)


def test_decode_invalid_token():
    result = decode_access_token("token.invalido.aqui")
    assert result is None


def test_create_token_with_string():
    sub = "some-string-id"
    token = create_access_token(sub)
    decoded = decode_access_token(token)
    assert decoded == sub
