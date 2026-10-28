"""Testes de autenticação: login, JWT, /me."""


async def test_login_sucesso(client, admin_user):
    r = await client.post(
        "/auth/login",
        json={
            "email": admin_user.email,
            "password": "admin123",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data.get("streak_bonus_points", -1) >= 0


async def test_login_email_invalido(client):
    r = await client.post(
        "/auth/login",
        json={
            "email": "naoexiste@test.com",
            "password": "qualquer",
        },
    )
    assert r.status_code == 401


async def test_login_senha_errada(client, admin_user):
    r = await client.post(
        "/auth/login",
        json={
            "email": admin_user.email,
            "password": "senhaerrada",
        },
    )
    assert r.status_code == 401


async def test_me_sem_token(client):
    r = await client.get("/auth/me")
    assert r.status_code == 401


async def test_me_com_token(client, admin_user, admin_headers):
    r = await client.get("/auth/me", headers=admin_headers)
    assert r.status_code == 200
    data = r.json()
    assert data["email"] == admin_user.email
    assert data["role"] == "administrador"
    assert "login_streak_days" in data
    assert isinstance(data["login_streak_days"], int)


async def test_me_token_invalido(client):
    r = await client.get("/auth/me", headers={"Authorization": "Bearer tokeninvalido"})
    assert r.status_code == 401


async def test_patch_me_gallery_visible(client, admin_headers, admin_user):
    """PATCH /auth/me atualiza gallery_visible do usuário autenticado."""
    r = await client.patch("/auth/me", headers=admin_headers, json={"gallery_visible": False})
    assert r.status_code == 200
    data = r.json()
    assert data["gallery_visible"] is False
    r2 = await client.get("/auth/me", headers=admin_headers)
    assert r2.json()["gallery_visible"] is False
    r3 = await client.patch("/auth/me", headers=admin_headers, json={"gallery_visible": True})
    assert r3.json()["gallery_visible"] is True


# ---------------------------------------------------------------------------
# Renovação e invalidação do token
# ---------------------------------------------------------------------------


def _bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def test_refresh_devolve_token_novo_que_funciona(client, aluno_user, aluno_headers):
    r = await client.post("/auth/refresh", headers=aluno_headers)
    assert r.status_code == 200
    novo = r.json()["access_token"]
    me = await client.get("/auth/me", headers=_bearer(novo))
    assert me.status_code == 200
    assert me.json()["id"] == str(aluno_user.id)


async def test_refresh_renova_a_validade(client, aluno_headers):
    from app.config import settings
    from app.core.security import decode_access_token

    r = await client.post("/auth/refresh", headers=aluno_headers)
    payload = decode_access_token(r.json()["access_token"])
    assert payload["exp"] - payload["iat"] == settings.JWT_EXPIRE_MINUTES * 60


async def test_refresh_ignora_impersonacao(client, admin_user, admin_headers, aluno_user):
    """O admin em «Atuar como» renova o próprio token, nunca recebe o do aluno simulado."""
    from app.core.security import decode_access_token

    headers = {**admin_headers, "X-Impersonate-User": str(aluno_user.id)}
    r = await client.post("/auth/refresh", headers=headers)
    assert r.status_code == 200
    assert decode_access_token(r.json()["access_token"])["sub"] == str(admin_user.id)


async def test_refresh_sem_token(client):
    r = await client.post("/auth/refresh")
    assert r.status_code == 401


async def test_token_vencido_e_recusado(client, aluno_user):
    from datetime import UTC, datetime, timedelta

    from jose import jwt

    from app.config import settings
    from app.core.security import password_fingerprint

    past = datetime.now(UTC) - timedelta(minutes=1)
    token = jwt.encode(
        {
            "sub": str(aluno_user.id),
            "iat": past - timedelta(days=30),
            "exp": past,
            "pwv": password_fingerprint(aluno_user.password_hash),
        },
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )
    assert (await client.get("/auth/me", headers=_bearer(token))).status_code == 401
    assert (await client.post("/auth/refresh", headers=_bearer(token))).status_code == 401


async def test_trocar_a_senha_derruba_as_sessoes(client, db, aluno_user, aluno_headers):
    from app.core.security import hash_password_sync
    from app.services.user_service import set_password

    assert (await client.get("/auth/me", headers=aluno_headers)).status_code == 200
    await set_password(db, aluno_user.id, hash_password_sync("senha-nova-123"))

    assert (await client.get("/auth/me", headers=aluno_headers)).status_code == 401
    assert (await client.post("/auth/refresh", headers=aluno_headers)).status_code == 401
    r = await client.post("/auth/login", json={"email": aluno_user.email, "password": "senha-nova-123"})
    assert r.status_code == 200
    assert (await client.get("/auth/me", headers=_bearer(r.json()["access_token"]))).status_code == 200


async def test_reset_de_senha_por_email_derruba_as_sessoes(client, db, aluno_user, aluno_headers):
    from datetime import UTC, datetime, timedelta

    from app.models.password_reset_token import PasswordResetToken

    now = datetime.now(UTC)
    db.add(
        PasswordResetToken(
            user_id=aluno_user.id,
            token="reset-token-teste-" + str(aluno_user.id),
            expires_at=now + timedelta(minutes=30),
            created_at=now,
        )
    )
    await db.commit()
    r = await client.post(
        "/auth/reset-password",
        json={"token": "reset-token-teste-" + str(aluno_user.id), "new_password": "senha-nova-123"},
    )
    assert r.status_code == 200
    assert (await client.get("/auth/me", headers=aluno_headers)).status_code == 401


async def test_token_antigo_sem_validade_vale_ate_a_data_de_corte(client, aluno_user, monkeypatch):
    """Tokens emitidos antes da renovação existir: o app ainda consegue trocá-los."""
    from datetime import date

    from jose import jwt

    from app.config import settings
    from app.core import security

    legado = jwt.encode({"sub": str(aluno_user.id)}, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    monkeypatch.setattr(settings, "JWT_LEGACY_TOKENS_UNTIL", date(2026, 12, 31))

    monkeypatch.setattr(security, "today_in_app_tz", lambda: date(2026, 12, 31))
    assert (await client.get("/auth/me", headers=_bearer(legado))).status_code == 200
    r = await client.post("/auth/refresh", headers=_bearer(legado))
    assert r.status_code == 200
    assert "pwv" in security.decode_access_token(r.json()["access_token"])

    monkeypatch.setattr(security, "today_in_app_tz", lambda: date(2027, 1, 1))
    assert (await client.get("/auth/me", headers=_bearer(legado))).status_code == 401


# ---------------------------------------------------------------------------
# Bloqueio de login e IP real atrás do proxy
# ---------------------------------------------------------------------------


async def test_bloqueio_vale_para_o_email_no_mesmo_ip(client, aluno_user):
    from app.config import settings

    de_casa = {"X-Forwarded-For": "203.0.113.7"}
    for _ in range(settings.ACCOUNT_LOCKOUT_ATTEMPTS):
        r = await client.post("/auth/login", headers=de_casa, json={"email": aluno_user.email, "password": "errada"})
        assert r.status_code == 401
    r = await client.post("/auth/login", headers=de_casa, json={"email": aluno_user.email, "password": "aluno123"})
    assert r.status_code == 429


async def test_bloqueio_nao_trava_o_dono_da_conta_em_outro_ip(client, aluno_user):
    """Quem erra a senha de outra pessoa não impede essa pessoa de entrar de onde ela está."""
    from app.config import settings

    atacante = {"X-Forwarded-For": "198.51.100.66"}
    for _ in range(settings.ACCOUNT_LOCKOUT_ATTEMPTS + 1):
        await client.post("/auth/login", headers=atacante, json={"email": aluno_user.email, "password": "errada"})

    r = await client.post(
        "/auth/login",
        headers={"X-Forwarded-For": "203.0.113.7"},
        json={"email": aluno_user.email, "password": "aluno123"},
    )
    assert r.status_code == 200


async def test_rate_limit_conta_pelo_ip_real(client):
    """Cada IP real tem o próprio limite: estourar num IP não bloqueia os outros alunos."""
    from uuid import uuid4

    def forgot(ip: str):
        return client.post(
            "/auth/forgot-password",
            headers={"X-Forwarded-For": ip},
            json={"email": f"ninguem-{uuid4().hex[:8]}@test.com"},
        )

    for _ in range(5):  # limite de /auth/forgot-password: 5/hour
        assert (await forgot("203.0.113.50")).status_code == 200
    assert (await forgot("203.0.113.50")).status_code == 429
    assert (await forgot("203.0.113.51")).status_code == 200
