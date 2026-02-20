"""
Executa os arquivos .sql da pasta migrations/ em ordem numérica (001, 002, ...).
Mantém uma tabela _migrations para rastrear quais já foram aplicadas (versionamento).
Migrações só rodam UMA vez; novas migrações são detectadas automaticamente.
"""
import logging
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import text

logger = logging.getLogger(__name__)

_TRACKING_TABLE = "_migrations"

_CREATE_TRACKING = f"""
CREATE TABLE IF NOT EXISTS {_TRACKING_TABLE} (
    filename VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""


def _migrations_dir() -> Path:
    return Path(__file__).resolve().parent.parent / "migrations"


def _ordered_sql_files() -> list[Path]:
    root = _migrations_dir()
    if not root.exists():
        logger.warning("Pasta migrations não encontrada: %s", root)
        return []
    return sorted(root.glob("*.sql"))


def _split_statements(content: str) -> list[str]:
    """
    Divide o conteúdo SQL em comandos por ';' no fim de linha.
    Não divide dentro de blocos dollar-quoted ($$ ... $$) para preservar DO/plpgsql.
    """
    statements: list[str] = []
    current: list[str] = []
    i = 0
    in_dollar = False
    n = len(content)

    while i < n:
        if in_dollar:
            if content[i : i + 2] == "$$":
                current.append("$$")
                i += 2
                in_dollar = False
            else:
                current.append(content[i])
                i += 1
            continue
        if content[i : i + 2] == "$$":
            current.append("$$")
            i += 2
            in_dollar = True
            continue
        if content[i] == ";" and (i + 1 >= n or content[i + 1 :].lstrip().startswith(("\n", "\r", "--"))):
            st = "".join(current).strip()
            if st and not all(
                line.strip().startswith("--") or not line.strip() for line in st.splitlines()
            ):
                statements.append(st)
            current = []
            i += 1
            while i < n and content[i] in " \t\r\n":
                i += 1
            continue
        current.append(content[i])
        i += 1

    st = "".join(current).strip()
    if st and not all(
        line.strip().startswith("--") or not line.strip() for line in st.splitlines()
    ):
        statements.append(st)
    return statements


def _get_applied(conn) -> set[str]:
    """Retorna filenames já registrados na tabela de tracking."""
    rows = conn.execute(text(f"SELECT filename FROM {_TRACKING_TABLE}")).fetchall()
    return {r[0] for r in rows}


def _record_applied(conn, filename: str) -> None:
    conn.execute(
        text(f"INSERT INTO {_TRACKING_TABLE} (filename, applied_at) VALUES (:f, :t)"),
        {"f": filename, "t": datetime.now(timezone.utc)},
    )


def run_migrations(engine) -> None:
    """
    Aplica migrações pendentes. Idempotente: só executa .sql que ainda não
    constam na tabela _migrations. Cria a tabela de tracking automaticamente.
    """
    files = _ordered_sql_files()
    if not files:
        return

    with engine.connect() as conn:
        conn.execute(text(_CREATE_TRACKING))
        conn.commit()

        applied = _get_applied(conn)
        pending = [f for f in files if f.name not in applied]

        if not pending:
            logger.info("Nenhuma migração pendente (%d já aplicadas).", len(applied))
            return

        logger.info(
            "%d migração(ões) pendente(s) de %d total.",
            len(pending),
            len(files),
        )

        for path in pending:
            name = path.name
            try:
                sql = path.read_text(encoding="utf-8")
                statements = _split_statements(sql)
                for st in statements:
                    if st:
                        conn.execute(text(st + ";"))
                _record_applied(conn, name)
                conn.commit()
                logger.info("Migração aplicada: %s", name)
            except Exception as e:
                conn.rollback()
                logger.exception("Erro ao aplicar %s: %s", name, e)
                raise

    logger.info("Migrações concluídas.")
