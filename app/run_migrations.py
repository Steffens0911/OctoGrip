"""
Executa os arquivos .sql da pasta migrations/ em ordem numérica (001, 002, ...)
no startup da API, para manter o banco consistente em qualquer ambiente.
As migrações usam IF NOT EXISTS / ADD COLUMN IF NOT EXISTS, então são idempotentes.
"""
import logging
import re
from pathlib import Path

from sqlalchemy import text

logger = logging.getLogger(__name__)


def _migrations_dir() -> Path:
    """Pasta migrations na raiz do projeto (funciona local e no Docker)."""
    return Path(__file__).resolve().parent.parent / "migrations"


def _ordered_sql_files() -> list[Path]:
    """Lista arquivos .sql em migrations/ ordenados por nome (001, 002, ...)."""
    root = _migrations_dir()
    if not root.exists():
        logger.warning("Pasta migrations não encontrada: %s", root)
        return []
    files = sorted(root.glob("*.sql"))
    return files


def _split_statements(content: str) -> list[str]:
    """
    Divide o conteúdo SQL em comandos por ';' no fim de linha.
    Não divide dentro de blocos dollar-quoted ($$ ... $$) para preservar DO/plpgsql.
    """
    statements = []
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


def run_migrations(engine) -> None:
    """
    Executa todos os .sql da pasta migrations/ em ordem.
    Usa a engine do SQLAlchemy (sync). Idempotente se as migrações usam IF NOT EXISTS.
    """
    files = _ordered_sql_files()
    if not files:
        return

    logger.info("Aplicando %d migração(ões) em ordem...", len(files))
    with engine.connect() as conn:
        for path in files:
            name = path.name
            try:
                sql = path.read_text(encoding="utf-8")
                statements = _split_statements(sql)
                for st in statements:
                    if st:
                        conn.execute(text(st + ";"))
                conn.commit()
                logger.info("Migração aplicada: %s", name)
            except Exception as e:
                conn.rollback()
                logger.exception("Erro ao aplicar %s: %s", name, e)
                raise
    logger.info("Migrações concluídas.")
