"""Backup e restauração admin (/admin/backup/*)."""
import io
import shutil
import tempfile
import zipfile
from pathlib import Path

import pytest
from httpx import AsyncClient

import app.routes.admin_backup as admin_backup
from app.routes.admin_backup import safe_extract_zip


@pytest.mark.asyncio
async def test_backup_database_forbidden_for_non_admin(
    client: AsyncClient, professor_headers: dict
):
    r = await client.get("/admin/backup/database", headers=professor_headers)
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_backup_database_forbidden_for_aluno(client: AsyncClient, aluno_headers: dict):
    r = await client.get("/admin/backup/database", headers=aluno_headers)
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_backup_archive_forbidden_for_non_admin(
    client: AsyncClient, professor_headers: dict
):
    r = await client.get("/admin/backup/archive", headers=professor_headers)
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_backup_restore_forbidden_for_non_admin(
    client: AsyncClient, professor_headers: dict
):
    files = {"file": ("x.zip", b"PK\x05\x06" + b"\x00" * 18, "application/zip")}
    r = await client.post("/admin/backup/restore", headers=professor_headers, files=files)
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_backup_restore_rejects_non_zip_filename(client: AsyncClient, admin_headers: dict):
    files = {"file": ("not.zip.txt", b"hello", "application/octet-stream")}
    r = await client.post("/admin/backup/restore", headers=admin_headers, files=files)
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_backup_restore_rejects_bad_zip(client: AsyncClient, admin_headers: dict):
    files = {"file": ("bad.zip", b"not a real zip content", "application/zip")}
    r = await client.post("/admin/backup/restore", headers=admin_headers, files=files)
    assert r.status_code == 400


def test_safe_extract_zip_rejects_path_traversal():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("../../../evil.txt", b"x")
    buf.seek(0)
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(buf) as zf:
            with pytest.raises(ValueError, match="não permitido|traversal|inválida"):
                safe_extract_zip(zf, Path(tmp))


def test_build_full_backup_zip_includes_media_files(monkeypatch: pytest.MonkeyPatch):
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        media_root = tmp_path / "app_media"
        media_file = media_root / "academy_logos" / "academy-1.png"
        media_file.parent.mkdir(parents=True, exist_ok=True)
        media_file.write_bytes(b"fake-image")

        dump_path_holder = {"path": None}

        def _fake_pg_dump(out_path: str) -> None:
            out = Path(out_path)
            out.write_text("-- fake dump", encoding="utf-8")
            dump_path_holder["path"] = out

        monkeypatch.setattr(admin_backup, "_MEDIA_ROOT", media_root)
        monkeypatch.setattr(admin_backup, "_run_pg_dump_sync", _fake_pg_dump)

        zip_out = tmp_path / "backup.zip"
        admin_backup._build_full_backup_zip_sync(str(zip_out))

        with zipfile.ZipFile(zip_out, "r") as zf:
            names = set(zf.namelist())
            assert "database.sql" in names
            assert "media/academy_logos/academy-1.png" in names
            assert zf.read("media/academy_logos/academy-1.png") == b"fake-image"
        # Garantir que usamos o dump temporário criado pelo fluxo.
        assert dump_path_holder["path"] is not None


@pytest.mark.asyncio
async def test_backup_database_admin_returns_sql_when_pg_dump_available(
    client: AsyncClient, admin_headers: dict
):
    if not shutil.which("pg_dump"):
        pytest.skip("pg_dump não está no PATH (instale postgresql-client ou use Docker)")
    r = await client.get("/admin/backup/database", headers=admin_headers)
    assert r.status_code == 200
    assert r.headers.get("content-type", "").startswith("application/sql")
    cd = r.headers.get("content-disposition", "")
    assert "attachment" in cd
    assert ".sql" in cd
    body = r.text
    assert "PostgreSQL database dump" in body or "CREATE " in body or "--" in body[:500]


@pytest.mark.asyncio
async def test_backup_archive_admin_returns_zip_when_pg_dump_available(
    client: AsyncClient, admin_headers: dict
):
    if not shutil.which("pg_dump"):
        pytest.skip("pg_dump não está no PATH (instale postgresql-client ou use Docker)")
    r = await client.get("/admin/backup/archive", headers=admin_headers)
    assert r.status_code == 200
    assert r.headers.get("content-type", "").startswith("application/zip")
    cd = r.headers.get("content-disposition", "")
    assert ".zip" in cd
    zf = zipfile.ZipFile(io.BytesIO(r.content))
    names = zf.namelist()
    assert any(n == "database.sql" or n.endswith("/database.sql") for n in names)
    assert "database.sql" in names


@pytest.mark.asyncio
async def test_restore_failure_triggers_public_schema_repair_attempt(
    client: AsyncClient, admin_headers: dict, monkeypatch: pytest.MonkeyPatch
):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("database.sql", "-- teste")
    buf.seek(0)
    files = {"file": ("ok.zip", buf.getvalue(), "application/zip")}

    called = {"repair": 0}

    async def _fake_dispose() -> None:
        return None

    def _fake_restore(_extract_dir: Path) -> dict:
        raise RuntimeError("falha proposital no restore")

    def _fake_repair() -> None:
        called["repair"] += 1

    monkeypatch.setattr(admin_backup, "_dispose_sqlalchemy_pools", _fake_dispose)
    monkeypatch.setattr(admin_backup, "_restore_from_extracted_dir", _fake_restore)
    monkeypatch.setattr(admin_backup, "_ensure_public_schema_and_search_path_sync", _fake_repair)

    r = await client.post("/admin/backup/restore", headers=admin_headers, files=files)
    assert r.status_code == 503
    assert called["repair"] >= 1
