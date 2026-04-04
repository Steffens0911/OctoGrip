"""Backup e restauração (admin): pg_dump, ZIP com mídia, psql."""

import asyncio
import logging
import os
import shutil
import subprocess
import tempfile
import time
import zipfile
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import unquote, urlparse
from uuid import UUID

from sqlalchemy import text

from fastapi import APIRouter, Depends, File, Request, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse

from app.config import settings
from app.core.cors_policy import merge_json_response_headers
from app.core.exceptions import AppError, AuthenticationError, ForbiddenError
from app.core.rate_limit import limiter
from app.core.security import decode_access_token
from app.database import async_engine, sync_engine

logger = logging.getLogger(__name__)

router = APIRouter()

# Mesma raiz usada por app.main e rotas de academias: <repo>/app_media.
_BASE_DIR = Path(__file__).resolve().parent.parent.parent
_MEDIA_ROOT = _BASE_DIR / "app_media"


def _require_admin_bearer_no_db_session(request: Request) -> str:
    """
    Autentica admin sem manter sessão async aberta durante backup/restore.

    Evita lock em DROP SCHEMA causado por sessão `idle in transaction` no próprio request.
    """
    auth = request.headers.get("Authorization", "").strip()
    if not auth.lower().startswith("bearer "):
        raise AuthenticationError("Token de autenticação ausente ou inválido.")
    token = auth[7:].strip()
    user_id_str = decode_access_token(token)
    if not user_id_str:
        raise AuthenticationError("Token inválido ou expirado.")
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise AuthenticationError("Token inválido.")

    with sync_engine.connect() as conn:
        row = conn.execute(
            text("SELECT id, role FROM users WHERE id = :uid"),
            {"uid": str(user_id)},
        ).mappings().first()
    if not row:
        raise AuthenticationError("Usuário não encontrado.")
    if row.get("role") != "administrador":
        raise ForbiddenError("Acesso negado. Apenas administradores podem acessar este recurso.")
    return str(row["id"])


def _parse_database_url(url: str) -> tuple[str, int, str, str, str]:
    """host, port, user, password, database name."""
    parsed = urlparse(url)
    if parsed.scheme not in ("postgresql", "postgres"):
        raise ValueError("DATABASE_URL deve ser postgresql://")
    host = parsed.hostname or "localhost"
    port = parsed.port or 5432
    user = unquote(parsed.username or "")
    password = unquote(parsed.password or "")
    dbname = (parsed.path or "/").lstrip("/").split("?")[0]
    if not dbname:
        raise ValueError("DATABASE_URL sem nome do banco")
    return host, port, user, password, dbname


def _run_pg_dump_sync(out_path: str) -> None:
    """Executa pg_dump para arquivo (thread pool). Levanta RuntimeError com mensagem em falha."""
    if not shutil.which("pg_dump"):
        raise RuntimeError(
            "pg_dump não está instalado ou não está no PATH. "
            "Em Docker, use a imagem da API com postgresql-client; em Windows local, instale o cliente PostgreSQL ou use Docker.",
        )
    host, port, user, password, dbname = _parse_database_url(settings.DATABASE_URL)
    env = {**os.environ, "PGPASSWORD": password}
    cmd = [
        "pg_dump",
        "-h",
        host,
        "-p",
        str(port),
        "-U",
        user,
        "-d",
        dbname,
        "--no-owner",
        "--no-acl",
        "-f",
        out_path,
    ]
    try:
        result = subprocess.run(
            cmd,
            env=env,
            capture_output=True,
            text=True,
            timeout=3600,
            check=False,
        )
    except subprocess.TimeoutExpired as e:
        raise RuntimeError("pg_dump excedeu o tempo máximo (1h).") from e
    except FileNotFoundError as e:
        raise RuntimeError("pg_dump não encontrado.") from e
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "pg_dump falhou").strip()
        logger.error("pg_dump rc=%s stderr=%s", result.returncode, err[:2000])
        raise RuntimeError(err[:4000] if err else "pg_dump falhou")


def _build_full_backup_zip_sync(zip_out_path: str) -> None:
    """Gera ZIP com database.sql + pasta media/ (cópia de app_media)."""
    work = Path(tempfile.mkdtemp(prefix="jjb_backup_zip_"))
    media_files = 0
    try:
        sql_path = work / "dump.sql"
        _run_pg_dump_sync(str(sql_path))
        with zipfile.ZipFile(zip_out_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(sql_path, "database.sql")
            if _MEDIA_ROOT.exists():
                for root, _dirs, files in os.walk(_MEDIA_ROOT):
                    for fname in files:
                        fp = Path(root) / fname
                        arc = Path("media") / fp.relative_to(_MEDIA_ROOT)
                        zf.write(fp, arc.as_posix())
                        media_files += 1
        if not _MEDIA_ROOT.exists():
            logger.warning(
                "Backup ZIP: pasta app_media não existe em %s — arquivo só terá database.sql.",
                _MEDIA_ROOT,
            )
        elif media_files == 0:
            logger.warning(
                "Backup ZIP: app_media em %s existe mas não tem ficheiros — arquivo só terá database.sql.",
                _MEDIA_ROOT,
            )
        else:
            logger.info(
                "Backup ZIP: incluídos %s ficheiro(s) em media/ (origem %s).",
                media_files,
                _MEDIA_ROOT,
            )
    finally:
        shutil.rmtree(work, ignore_errors=True)


def _zip_entry_is_safe(filename: str) -> bool:
    if not filename or filename.startswith("/"):
        return False
    p = Path(filename)
    if ".." in p.parts:
        return False
    return True


def safe_extract_zip(zf: zipfile.ZipFile, dest: Path) -> None:
    """Extrai ZIP com proteção contra zip slip."""
    dest_resolved = dest.resolve()
    for info in zf.infolist():
        name = info.filename
        if info.is_dir():
            name = name.rstrip("/")
        if not _zip_entry_is_safe(name):
            raise ValueError("Entrada ZIP inválida (caminho não permitido).")
        target = (dest_resolved / name).resolve()
        try:
            target.relative_to(dest_resolved)
        except ValueError as e:
            raise ValueError("Entrada ZIP inválida (path traversal).") from e
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(info) as src, open(target, "wb") as out_f:
            shutil.copyfileobj(src, out_f)


def _psql_env(password: str) -> dict[str, str]:
    return {**os.environ, "PGPASSWORD": password}


def _psql_cmd_base(host: str, port: int, user: str, dbname: str) -> list[str]:
    return [
        "psql",
        "-h",
        host,
        "-p",
        str(port),
        "-U",
        user,
        "-d",
        dbname,
        "-v",
        "ON_ERROR_STOP=1",
    ]


def _log_psql_streams(label: str, stdout: str | None, stderr: str | None) -> str:
    """Log completo (últimos 64k se enorme) e excerto para resposta AppError."""
    parts: list[str] = []
    if stderr and stderr.strip():
        parts.append(f"[stderr]\n{stderr.strip()}")
    if stdout and stdout.strip():
        parts.append(f"[stdout]\n{stdout.strip()}")
    blob = "\n\n".join(parts) if parts else "(psql não devolveu texto em stdout/stderr)"
    if len(blob) > 64000:
        logger.error(
            "%s — saída psql truncada no log (total %s chars), últimos 64000:\n%s",
            label,
            len(blob),
            blob[-64000:],
        )
    else:
        logger.error("%s — saída psql:\n%s", label, blob)
    return blob[:12000]


def _verify_psql_connection_sync(
    host: str,
    port: int,
    user: str,
    password: str,
    dbname: str,
) -> None:
    """Várias tentativas de SELECT 1 antes do restore (rede/DNS/postgres a iniciar)."""
    env = _psql_env(password)
    cmd = [
        *_psql_cmd_base(host, port, user, dbname),
        "-c",
        "SELECT 1 AS jjb_connection_check;",
    ]
    retries = max(1, settings.BACKUP_PSQL_CONNECT_RETRIES)
    delay = max(0.5, settings.BACKUP_PSQL_CONNECT_RETRY_DELAY_SEC)
    last_err = ""
    for attempt in range(1, retries + 1):
        try:
            r = subprocess.run(
                cmd,
                env=env,
                capture_output=True,
                text=True,
                timeout=45,
            )
            if r.returncode == 0:
                logger.info(
                    "Restore: PostgreSQL acessível (tentativa %s/%s host=%s db=%s)",
                    attempt,
                    retries,
                    host,
                    dbname,
                )
                return
            last_err = (r.stderr or r.stdout or f"exit {r.returncode}").strip()
            logger.warning(
                "Restore: ping psql falhou (%s/%s): %s",
                attempt,
                retries,
                last_err[:800],
            )
        except subprocess.TimeoutExpired:
            last_err = "timeout (45s) no ping psql"
            logger.warning("Restore: ping psql timeout (%s/%s)", attempt, retries)
        except OSError as e:
            last_err = str(e)
            logger.warning("Restore: ping psql erro OS (%s/%s): %s", attempt, retries, e)
        if attempt < retries:
            time.sleep(delay)
    raise RuntimeError(
        f"Sem conexão ao PostgreSQL após {retries} tentativas "
        f"(host={host!r} port={port} database={dbname!r} user={user!r}). "
        f"No Compose, o host costuma ser `postgres`. Último erro: {last_err[:3000]}"
    )


# Sem pg_terminate_backend aqui: matar sessões do mesmo utilizador (jjb) incluiria ligações do
# pool asyncpg deste processo ainda associadas ao pedido HTTP — no fim do pedido o SQLAlchemy
# tenta rollback e obtém InterfaceError ("connection is closed").
# Libertação de ligações: await _dispose_sqlalchemy_pools() na rota antes do psql.
_RESTORE_SQL_PREAMBLE = """-- JJB restore (script gerado)
SET client_encoding = 'UTF8';

DO $$
BEGIN
  PERFORM pg_terminate_backend(pid)
    FROM pg_stat_activity
   WHERE datname = current_database()
     AND pid <> pg_backend_pid()
     AND state IN ('idle in transaction', 'idle in transaction (aborted)');
END $$;

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
ALTER SCHEMA public OWNER TO CURRENT_USER;
GRANT ALL ON SCHEMA public TO CURRENT_USER;
GRANT USAGE ON SCHEMA public TO PUBLIC;

"""


def _write_combined_restore_script(dump_path: Path) -> Path:
    """Preamble + dump num único ficheiro (stream, adequado a dumps grandes)."""
    fd, raw = tempfile.mkstemp(prefix="jjb_restore_all_", suffix=".sql")
    os.close(fd)
    combined = Path(raw)
    try:
        combined.write_bytes(_RESTORE_SQL_PREAMBLE.encode("utf-8"))
        with open(combined, "ab") as out:
            with open(dump_path, "rb") as src:
                shutil.copyfileobj(src, out, length=1024 * 1024)
        return combined
    except Exception:
        combined.unlink(missing_ok=True)
        raise


def _run_psql_restore_from_dump_file(sql_file: Path) -> None:
    """
    Restore: retries de ligação + um único `psql -f` (DROP/CREATE public + dump).
    A rota deve chamar _dispose_sqlalchemy_pools() antes, para não bloquear o DROP.
    Corre em thread pool (asyncio.to_thread) para não bloquear o event loop.
    """
    if not shutil.which("psql"):
        raise RuntimeError(
            "psql não está instalado ou não está no PATH. Em Docker, use a imagem da API com postgresql-client.",
        )
    host, port, user, password, dbname = _parse_database_url(settings.DATABASE_URL)
    env = _psql_env(password)

    _verify_psql_connection_sync(host, port, user, password, dbname)

    combined: Path | None = None
    timeout_sec = max(300, settings.BACKUP_PSQL_RESTORE_TIMEOUT_SEC)
    proc: subprocess.CompletedProcess[str] | None = None
    try:
        combined = _write_combined_restore_script(sql_file)
        cmd = [*_psql_cmd_base(host, port, user, dbname), "-f", str(combined)]
        logger.info(
            "Restore: psql -f (timeout=%ss, host=%s db=%s, ficheiro=%s bytes)",
            timeout_sec,
            host,
            dbname,
            combined.stat().st_size,
        )
        proc = subprocess.run(
            cmd,
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired as e:
        raise RuntimeError(
            f"Timeout ({timeout_sec}s) no restore (psql -f). "
            "Aumente BACKUP_PSQL_RESTORE_TIMEOUT_SEC ou verifique tamanho do dump / carga do servidor."
        ) from e
    finally:
        if combined is not None:
            try:
                combined.unlink(missing_ok=True)
            except OSError:
                pass

    if proc is None:
        raise RuntimeError("Restore interno: subprocesso psql não produziu resultado.")
    if proc.returncode != 0:
        excerpt = _log_psql_streams("Restore psql falhou", proc.stdout, proc.stderr)
        raise RuntimeError(
            f"psql exit {proc.returncode}. Excerto:\n{excerpt}"
        )

    logger.info("Restore: psql concluído (rc=0).")


def _ensure_public_schema_and_search_path_sync() -> None:
    """
    Pós-restore defensivo:
    - garante schema public existente e com owner/permissões básicas;
    - força search_path default do banco para public.
    """
    host, port, user, password, dbname = _parse_database_url(settings.DATABASE_URL)
    env = _psql_env(password)
    sql = """
CREATE SCHEMA IF NOT EXISTS public;
ALTER SCHEMA public OWNER TO CURRENT_USER;
GRANT ALL ON SCHEMA public TO CURRENT_USER;
GRANT USAGE ON SCHEMA public TO PUBLIC;
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET search_path TO public', current_database());
END $$;
"""
    cmd = [*_psql_cmd_base(host, port, user, dbname), "-c", sql]
    try:
        r = subprocess.run(
            cmd,
            env=env,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except Exception as e:
        raise RuntimeError(
            f"Falha ao validar schema/public search_path após restore: {e}"
        ) from e
    if r.returncode != 0:
        excerpt = _log_psql_streams("Pós-restore: garantir public/search_path falhou", r.stdout, r.stderr)
        raise RuntimeError(
            f"Não foi possível garantir schema public/search_path após restore. Excerto:\n{excerpt}"
        )


def _sync_media_from_zip(media_src: Path, media_dest: Path) -> bool:
    """
    Substitui conteúdo de app_media pelos ficheiros em media_src.
    Se media_src não existir ou não tiver ficheiros, não altera app_media.
    """
    if not media_src.is_dir():
        return False
    if not any(p.is_file() for p in media_src.rglob("*")):
        return False
    media_dest.mkdir(parents=True, exist_ok=True)
    for item in list(media_dest.iterdir()):
        if item.is_dir():
            shutil.rmtree(item)
        else:
            item.unlink(missing_ok=True)
    for item in media_src.iterdir():
        dest = media_dest / item.name
        if item.is_dir():
            shutil.copytree(item, dest)
        else:
            shutil.copy2(item, dest)
    return True


def _restore_from_extracted_dir(extract_dir: Path) -> dict:
    sql_path = extract_dir / "database.sql"
    if not sql_path.is_file():
        raise RuntimeError("O ZIP deve conter database.sql na raiz.")
    _run_psql_restore_from_dump_file(sql_path)
    try:
        restored = _sync_media_from_zip(extract_dir / "media", _MEDIA_ROOT)
    except OSError as e:
        raise RuntimeError(f"Falha ao sincronizar mídia em app_media: {e}") from e
    return {"ok": True, "restored_media": restored}


async def _dispose_sqlalchemy_pools() -> None:
    """
    Fecha todas as ligações em pool para este processo.

    Antes do restore: o DROP SCHEMA public CASCADE fica bloqueado enquanto existirem sessões
    da própria API (async + sync engine) com o banco aberto.

    Depois do restore: ligações antigas apontam para um schema que deixou de existir.
    """
    await async_engine.dispose()
    await asyncio.to_thread(sync_engine.dispose)


@router.get("/backup/database")
@limiter.limit(settings.BACKUP_DOWNLOAD_RATE_LIMIT)
async def admin_download_database_backup(
    request: Request,
    _admin_id: str = Depends(_require_admin_bearer_no_db_session),
):
    """
    Gera dump SQL completo do banco (plain) e envia como download.

    Não inclui app_media. Apenas administradores.
    """
    _ = request
    fd, path = tempfile.mkstemp(prefix="jjb_pg_dump_", suffix=".sql")
    os.close(fd)
    try:
        await asyncio.to_thread(_run_pg_dump_sync, path)
    except RuntimeError as e:
        try:
            os.unlink(path)
        except OSError:
            pass
        raise AppError(str(e), status_code=503) from e
    except Exception:
        try:
            os.unlink(path)
        except OSError:
            pass
        raise

    stamp = datetime.now(UTC).strftime("%Y%m%d_%H%M%S")
    filename = f"jjb_backup_{stamp}.sql"

    async def file_chunks():
        try:
            with open(path, "rb") as f:
                while True:
                    chunk = f.read(65536)
                    if not chunk:
                        break
                    yield chunk
        finally:
            try:
                os.unlink(path)
            except OSError:
                pass

    return StreamingResponse(
        file_chunks(),
        media_type="application/sql",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-store",
        },
    )


@router.get("/backup/archive")
@limiter.limit(settings.BACKUP_DOWNLOAD_RATE_LIMIT)
async def admin_download_backup_archive(
    request: Request,
    _admin_id: str = Depends(_require_admin_bearer_no_db_session),
):
    """
    ZIP com database.sql + pasta media/ (logos e imagens de horários em app_media).
    """
    _ = request
    fd, zpath = tempfile.mkstemp(prefix="jjb_full_backup_", suffix=".zip")
    os.close(fd)
    try:
        await asyncio.to_thread(_build_full_backup_zip_sync, zpath)
    except RuntimeError as e:
        try:
            os.unlink(zpath)
        except OSError:
            pass
        raise AppError(str(e), status_code=503) from e
    except Exception:
        try:
            os.unlink(zpath)
        except OSError:
            pass
        raise

    stamp = datetime.now(UTC).strftime("%Y%m%d_%H%M%S")
    filename = f"jjb_backup_{stamp}.zip"

    async def file_chunks():
        try:
            with open(zpath, "rb") as f:
                while True:
                    chunk = f.read(65536)
                    if not chunk:
                        break
                    yield chunk
        finally:
            try:
                os.unlink(zpath)
            except OSError:
                pass

    return StreamingResponse(
        file_chunks(),
        media_type="application/zip",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-store",
        },
    )


@router.post("/backup/restore")
async def admin_restore_backup(
    request: Request,
    _admin_id: str = Depends(_require_admin_bearer_no_db_session),
    file: UploadFile = File(..., description="Arquivo .zip do backup completo"),
):
    """
    Restaura database.sql (recria schema public) e opcionalmente mídia em app_media.

    Operação destrutiva: apaga todos os dados atuais do banco.

    Sem @limiter aqui: slowapi + multipart grande pode falhar de forma opaca (500) e o browser
    acusa CORS; o tamanho máximo do ZIP e a exigência de admin já limitam abuso.
    """
    _ = request
    if not file.filename or not file.filename.lower().endswith(".zip"):
        raise AppError("Envie um arquivo .zip.", status_code=422)

    max_bytes = settings.BACKUP_RESTORE_MAX_MB * 1024 * 1024
    fd, tmpzip = tempfile.mkstemp(prefix="jjb_restore_", suffix=".zip")
    os.close(fd)
    total = 0
    try:
        with open(tmpzip, "wb") as out:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > max_bytes:
                    raise AppError(
                        f"Arquivo excede o limite de {settings.BACKUP_RESTORE_MAX_MB} MB.",
                        status_code=413,
                    )
                out.write(chunk)
    except AppError:
        try:
            os.unlink(tmpzip)
        except OSError:
            pass
        raise
    except OSError as e:
        try:
            os.unlink(tmpzip)
        except OSError:
            pass
        raise AppError(f"Erro ao gravar o arquivo enviado: {e}", status_code=507) from e
    except Exception:
        try:
            os.unlink(tmpzip)
        except OSError:
            pass
        raise

    extract_root = Path(tempfile.mkdtemp(prefix="jjb_restore_extract_"))
    try:
        with zipfile.ZipFile(tmpzip, "r") as zf:
            safe_extract_zip(zf, extract_root)
    except (zipfile.BadZipFile, ValueError) as e:
        shutil.rmtree(extract_root, ignore_errors=True)
        try:
            os.unlink(tmpzip)
        except OSError:
            pass
        raise AppError(f"ZIP inválido: {e}", status_code=400) from e
    except Exception:
        shutil.rmtree(extract_root, ignore_errors=True)
        try:
            os.unlink(tmpzip)
        except OSError:
            pass
        raise
    finally:
        try:
            os.unlink(tmpzip)
        except OSError:
            pass

    try:
        await _dispose_sqlalchemy_pools()
    except Exception as e:
        logger.exception("Falha ao fechar pools SQLAlchemy antes do restore")
        raise AppError(
            "Não foi possível libertar ligações à base de dados antes da restauração. Tente de novo ou reinicie a API.",
            status_code=503,
        ) from e

    try:
        result = await asyncio.to_thread(_restore_from_extracted_dir, extract_root)
    except RuntimeError as e:
        # Já houve dispose antes do psql; voltar a libertar o que o driver puder ter reaberto.
        try:
            await asyncio.to_thread(_ensure_public_schema_and_search_path_sync)
        except Exception:
            logger.exception("Pós-erro restore: falha ao auto-reparar schema public/search_path")
        try:
            await _dispose_sqlalchemy_pools()
        except Exception:
            logger.exception("Falha ao descartar pools após restore com erro")
        raise AppError(str(e), status_code=503) from e
    finally:
        shutil.rmtree(extract_root, ignore_errors=True)

    try:
        await _dispose_sqlalchemy_pools()
    except Exception:
        logger.exception(
            "Falha ao descartar pools SQLAlchemy após restore; próximas requisições podem falhar até reiniciar a API"
        )

    try:
        await asyncio.to_thread(_ensure_public_schema_and_search_path_sync)
    except RuntimeError as e:
        raise AppError(str(e), status_code=503) from e

    # Garantir que o pool async volta a ter ligações válidas (evita ERR_EMPTY_RESPONSE no próximo login).
    try:
        async with async_engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception as e:
        logger.exception("Pós-restore: falha ao validar ligação ao PostgreSQL")
        raise AppError(
            "A base pode ter sido restaurada, mas a API não restabeleceu a ligação ao PostgreSQL. "
            "Reinicie o contentor da API (ex.: docker compose restart api).",
            status_code=503,
        ) from e

    logger.warning(
        "Backup restaurado por admin user_id=%s restored_media=%s",
        _admin_id,
        result.get("restored_media"),
    )
    return JSONResponse(result, headers=merge_json_response_headers(request, None))
