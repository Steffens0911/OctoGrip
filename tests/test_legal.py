"""Testes dos documentos legais públicos servidos pela API (/legal)."""

from httpx import AsyncClient


async def test_get_privacy_document(client: AsyncClient):
    r = await client.get("/legal/privacy")
    assert r.status_code == 200
    body = r.json()
    assert body["slug"] == "privacy"
    assert body["version"]
    assert body["contact_email"]
    assert "Política de Privacidade" in body["content_markdown"]


async def test_get_biometric_document(client: AsyncClient):
    r = await client.get("/legal/biometric")
    assert r.status_code == 200
    assert "biométrico" in r.json()["content_markdown"].lower()


async def test_unknown_document_returns_404(client: AsyncClient):
    r = await client.get("/legal/inexistente")
    assert r.status_code == 404


async def test_view_endpoint_returns_html(client: AsyncClient):
    r = await client.get("/legal/terms/view")
    assert r.status_code == 200
    assert "text/html" in r.headers["content-type"]
    assert "<h1>" in r.text
