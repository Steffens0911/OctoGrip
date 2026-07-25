"""Testes de health check."""

from app.database import get_db
from app.main import app


async def test_health_ok(client):
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


async def test_health_db(client):
    r = await client.get("/health/db")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert data["database"] == "connected"


async def test_health_db_banco_fora_retorna_503(client):
    """Monitores de uptime dependem do status HTTP: banco fora => 503, não 200."""

    class _SessaoBancoFora:
        async def execute(self, *args, **kwargs):
            raise ConnectionError("simulando banco indisponível")

    async def _override_banco_fora():
        yield _SessaoBancoFora()

    override_anterior = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = _override_banco_fora
    try:
        r = await client.get("/health/db")
    finally:
        app.dependency_overrides[get_db] = override_anterior

    assert r.status_code == 503
    data = r.json()
    assert data["status"] == "error"
    assert "db_latency_ms" in data
