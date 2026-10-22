"""Versão do app: /app/config, bloqueio 426 abaixo da mínima, registro da versão por usuário e admin."""

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import delete

from app.core.app_version import is_version_below, parse_app_version
from app.models import AppConfig
from app.services.app_config_service import clear_app_config_cache


@pytest.fixture(autouse=True)
async def _clean_app_config(db):
    await db.execute(delete(AppConfig))
    await db.commit()
    await clear_app_config_cache()
    yield
    await db.execute(delete(AppConfig))
    await db.commit()
    await clear_app_config_cache()


async def _set_android_min(db, min_version: str, latest_version: str | None = None) -> None:
    db.add(
        AppConfig(
            platform="android",
            min_version=min_version,
            latest_version=latest_version or min_version,
            store_url="https://play.google.com/store/apps/details?id=br.com.octogrip.app",
            feature_flags={},
        )
    )
    await db.commit()
    await clear_app_config_cache()


def _app(version: str, platform: str = "android") -> dict:
    return {"X-App-Version": version, "X-App-Platform": platform}


# ---------------------------------------------------------------------------
# Comparação de versões
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("1.3.0+12", (1, 3, 0, 12)),
        ("1.3.0", (1, 3, 0, 0)),
        (" 2.0.1+3 ", (2, 0, 1, 3)),
        ("1.3", None),
        ("v1.3.0", None),
        ("", None),
        (None, None),
    ],
)
def test_parse_app_version(raw, expected):
    assert parse_app_version(raw) == expected


@pytest.mark.parametrize(
    ("version", "minimum", "below"),
    [
        ("1.2.9+40", "1.3.0", True),
        ("1.3.0+1", "1.3.0", False),  # mínima sem build aceita qualquer build da mesma versão
        ("1.3.0+11", "1.3.0+12", True),
        ("1.10.0", "1.9.0", False),  # comparação numérica, não de texto
        ("lixo", "1.3.0", False),  # versão malformada nunca bloqueia
        (None, "1.3.0", False),
    ],
)
def test_is_version_below(version, minimum, below):
    assert is_version_below(version, minimum) is below


# ---------------------------------------------------------------------------
# GET /app/config
# ---------------------------------------------------------------------------


async def test_app_config_defaults_when_not_configured(client):
    r = await client.get("/app/config", params={"platform": "android"})
    assert r.status_code == 200
    body = r.json()
    assert body["min_version"] == "0.0.0"
    assert body["feature_flags"] == {}


async def test_app_config_returns_stored_values(client, db):
    await _set_android_min(db, "1.3.0", "1.4.0+20")
    r = await client.get("/app/config", params={"platform": "android"})
    assert r.status_code == 200
    body = r.json()
    assert body["min_version"] == "1.3.0"
    assert body["latest_version"] == "1.4.0+20"
    assert "br.com.octogrip.app" in body["store_url"]


async def test_app_config_rejects_unknown_platform(client):
    r = await client.get("/app/config", params={"platform": "symbian"})
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Bloqueio 426
# ---------------------------------------------------------------------------


async def test_old_app_gets_426_with_update_info(client, db, aluno_headers):
    await _set_android_min(db, "1.3.0")
    r = await client.get("/auth/me", headers=aluno_headers | _app("1.2.0+8"))
    assert r.status_code == 426
    body = r.json()
    assert body["error"]["type"] == "AppUpdateRequiredError"
    assert body["update"]["min_version"] == "1.3.0"
    assert "br.com.octogrip.app" in body["update"]["store_url"]


async def test_current_app_passes(client, db, aluno_headers):
    await _set_android_min(db, "1.3.0")
    r = await client.get("/auth/me", headers=aluno_headers | _app("1.3.0+12"))
    assert r.status_code == 200


async def test_requests_without_version_headers_are_never_blocked(client, db, aluno_headers):
    """Web e versões antigas do app (sem header) continuam funcionando."""
    await _set_android_min(db, "9.0.0")
    r = await client.get("/auth/me", headers=aluno_headers)
    assert r.status_code == 200


async def test_platform_without_config_is_not_blocked(client, db, aluno_headers):
    await _set_android_min(db, "9.0.0")
    r = await client.get("/auth/me", headers=aluno_headers | _app("1.0.0", platform="web"))
    assert r.status_code == 200


async def test_old_app_can_still_read_app_config_and_health(client, db):
    await _set_android_min(db, "9.0.0")
    r = await client.get("/app/config", params={"platform": "android"}, headers=_app("1.0.0"))
    assert r.status_code == 200
    r = await client.get("/health", headers=_app("1.0.0"))
    assert r.status_code == 200


async def test_old_app_blocked_on_public_route_too(client, db):
    """O bloqueio não depende de login: a tela de login de um app velho também recebe 426."""
    await _set_android_min(db, "9.0.0")
    r = await client.post(
        "/auth/login",
        json={"email": "x@test.com", "password": "x"},
        headers=_app("1.0.0"),
    )
    assert r.status_code == 426


# ---------------------------------------------------------------------------
# Registro da versão por usuário
# ---------------------------------------------------------------------------


async def test_records_app_version_on_authenticated_request(client, db, aluno_user, aluno_headers):
    r = await client.get("/auth/me", headers=aluno_headers | _app("1.3.0+12"))
    assert r.status_code == 200
    await db.refresh(aluno_user)
    assert aluno_user.last_app_version == "1.3.0+12"
    assert aluno_user.last_app_platform == "android"
    assert aluno_user.last_app_seen_at is not None


async def test_same_version_is_not_rewritten_within_a_day(client, db, aluno_user, aluno_headers):
    seen = datetime.now(UTC) - timedelta(hours=2)
    aluno_user.last_app_version = "1.3.0+12"
    aluno_user.last_app_platform = "android"
    aluno_user.last_app_seen_at = seen
    await db.commit()

    await client.get("/auth/me", headers=aluno_headers | _app("1.3.0+12"))
    await db.refresh(aluno_user)
    assert aluno_user.last_app_seen_at == seen

    await client.get("/auth/me", headers=aluno_headers | _app("1.4.0+13"))
    await db.refresh(aluno_user)
    assert aluno_user.last_app_version == "1.4.0+13"
    assert aluno_user.last_app_seen_at > seen


async def test_malformed_version_is_not_recorded(client, db, aluno_user, aluno_headers):
    r = await client.get("/auth/me", headers=aluno_headers | _app("abc"))
    assert r.status_code == 200
    await db.refresh(aluno_user)
    assert aluno_user.last_app_version is None


# ---------------------------------------------------------------------------
# Admin
# ---------------------------------------------------------------------------


async def test_admin_updates_config_and_block_applies_immediately(client, admin_headers, aluno_headers):
    r = await client.put(
        "/admin/app-config/android",
        json={"min_version": "1.3.0", "latest_version": "1.4.0+20", "update_message": "Atualize!"},
        headers=admin_headers,
    )
    assert r.status_code == 200
    assert r.json()["min_version"] == "1.3.0"

    r = await client.get("/auth/me", headers=aluno_headers | _app("1.2.0"))
    assert r.status_code == 426
    assert r.json()["detail"] == "Atualize!"


async def test_admin_partial_update_keeps_other_fields(client, db, admin_headers):
    await _set_android_min(db, "1.3.0", "1.4.0")
    r = await client.put(
        "/admin/app-config/android",
        json={"feature_flags": {"novo_ranking": {"enabled": True, "min_app_version": "1.4.0"}}},
        headers=admin_headers,
    )
    assert r.status_code == 200
    body = r.json()
    assert body["min_version"] == "1.3.0"
    assert body["feature_flags"]["novo_ranking"]["enabled"] is True


@pytest.mark.parametrize(
    "payload",
    [
        {"min_version": "1.3"},
        {"latest_version": "v2"},
        {"min_version": "2.0.0", "latest_version": "1.0.0"},
    ],
)
async def test_admin_rejects_invalid_versions(client, admin_headers, payload):
    r = await client.put("/admin/app-config/android", json=payload, headers=admin_headers)
    assert r.status_code == 422


async def test_admin_rejects_min_above_stored_latest(client, db, admin_headers):
    await _set_android_min(db, "1.0.0", "1.2.0")
    r = await client.put("/admin/app-config/android", json={"min_version": "1.5.0"}, headers=admin_headers)
    assert r.status_code == 422


async def test_non_admin_cannot_change_config(client, professor_headers):
    r = await client.put("/admin/app-config/android", json={"min_version": "1.0.0"}, headers=professor_headers)
    assert r.status_code == 403


async def test_admin_app_versions_distribution(client, db, admin_headers, aluno_user, professor_user):
    now = datetime.now(UTC)
    aluno_user.last_app_version = "7.7.7+77"
    aluno_user.last_app_platform = "android"
    aluno_user.last_app_seen_at = now
    professor_user.last_app_version = "7.7.7+77"
    professor_user.last_app_platform = "android"
    professor_user.last_app_seen_at = now - timedelta(days=90)  # fora da janela
    await db.commit()

    r = await client.get("/admin/app-versions", params={"days": 30}, headers=admin_headers)
    assert r.status_code == 200
    rows = [v for v in r.json()["versions"] if v["version"] == "7.7.7+77"]
    assert rows == [{"platform": "android", "version": "7.7.7+77", "users": 1}]
