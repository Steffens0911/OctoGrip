"""Bloqueio de login por e-mail + IP (fallback em memória, sem Redis)."""

from app.core import login_lockout as lockout_module
from app.core.login_lockout import LoginLockout


def _lockout(max_attempts: int = 3, window_seconds: int = 900) -> LoginLockout:
    return LoginLockout(max_attempts=max_attempts, window_seconds=window_seconds, storage_uri="memory://")


async def test_bloqueia_apos_o_limite_de_falhas():
    lk = _lockout()
    for _ in range(3):
        assert not await lk.is_locked("aluno@x.com", "203.0.113.7")
        await lk.record_failure("aluno@x.com", "203.0.113.7")
    assert await lk.is_locked("aluno@x.com", "203.0.113.7")


async def test_outro_ip_nao_fica_bloqueado():
    """Errar a senha de alguém de outro lugar não trava a conta dessa pessoa."""
    lk = _lockout()
    for _ in range(3):
        await lk.record_failure("aluno@x.com", "203.0.113.7")
    assert not await lk.is_locked("aluno@x.com", "198.51.100.20")


async def test_email_sem_diferenca_de_maiusculas_e_espacos():
    lk = _lockout()
    for _ in range(3):
        await lk.record_failure(" Aluno@X.com ", "203.0.113.7")
    assert await lk.is_locked("aluno@x.com", "203.0.113.7")


async def test_login_certo_limpa_as_falhas():
    lk = _lockout()
    for _ in range(2):
        await lk.record_failure("aluno@x.com", "203.0.113.7")
    await lk.clear("aluno@x.com", "203.0.113.7")
    await lk.record_failure("aluno@x.com", "203.0.113.7")
    assert not await lk.is_locked("aluno@x.com", "203.0.113.7")


async def test_falhas_antigas_saem_da_janela(monkeypatch):
    lk = _lockout(window_seconds=60)
    clock = [1000.0]
    monkeypatch.setattr(lockout_module.time, "monotonic", lambda: clock[0])
    for _ in range(3):
        await lk.record_failure("aluno@x.com", "203.0.113.7")
    assert await lk.is_locked("aluno@x.com", "203.0.113.7")
    clock[0] += 61
    assert not await lk.is_locked("aluno@x.com", "203.0.113.7")


async def test_memoria_tem_teto_de_chaves(monkeypatch):
    monkeypatch.setattr(lockout_module, "_MEMORY_MAX_KEYS", 5)
    lk = _lockout()
    for i in range(20):
        await lk.record_failure(f"inventado{i}@x.com", "203.0.113.7")
    assert len(lk._memory) == 5


async def test_redis_fora_do_ar_cai_para_a_memoria():
    """Porta sem Redis: o login segue protegido pela contagem em memória."""
    lk = LoginLockout(max_attempts=2, window_seconds=900, storage_uri="redis://127.0.0.1:1/0")
    for _ in range(2):
        await lk.record_failure("aluno@x.com", "203.0.113.7")
    assert await lk.is_locked("aluno@x.com", "203.0.113.7")
    await lk.clear("aluno@x.com", "203.0.113.7")
    assert not await lk.is_locked("aluno@x.com", "203.0.113.7")
