"""Migration 091 no cenário real do bootstrap: create_all roda ANTES das migrations.

Em produção a tabela app_config já existia (criada pelo modelo, sem padrões no banco) quando a
migration rodou, e o INSERT do Android violava o NOT NULL: a migration falhava e a API não subia.
Os demais testes não pegam isso porque criam o schema com create_all e nunca rodam as migrations.

Executa pelo mesmo caminho da produção (engine síncrono psycopg2, via run_migrations) dentro de uma
transação que sofre rollback, então o banco de teste não muda.
"""

from pathlib import Path

import pytest
from sqlalchemy import text

from app.database import engine
from app.run_migrations import _split_statements

MIGRATION = Path(__file__).resolve().parent.parent / "migrations" / "091_app_config_and_app_version.sql"
ANDROID = "SELECT min_version, latest_version, feature_flags FROM app_config WHERE platform = 'android'"


@pytest.fixture
def conn():
    """Conexão síncrona; tudo que o teste fizer (inclusive DDL) é desfeito no fim."""
    connection = engine.connect()
    try:
        yield connection
    finally:
        connection.rollback()
        connection.close()


def _run_migration(conn) -> None:
    for statement in _split_statements(MIGRATION.read_text(encoding="utf-8")):
        conn.execute(text(statement + ";"))


def test_migration_091_with_table_created_without_db_defaults(conn):
    """Estado exato de produção: tabela do modelo antigo, colunas NOT NULL sem DEFAULT."""
    conn.execute(text("DELETE FROM app_config"))
    for column in ("min_version", "latest_version", "feature_flags"):
        conn.execute(text(f"ALTER TABLE app_config ALTER COLUMN {column} DROP DEFAULT"))

    _run_migration(conn)

    row = conn.execute(text(ANDROID)).one_or_none()
    assert row is not None
    assert (row.min_version, row.latest_version, row.feature_flags) == ("0.0.0", "0.0.0", {})


def test_migration_091_restores_column_defaults(conn):
    """A migration também conserta a tabela já existente sem padrões (inserts futuros sem as colunas)."""
    conn.execute(text("DELETE FROM app_config"))
    for column in ("min_version", "latest_version", "feature_flags"):
        conn.execute(text(f"ALTER TABLE app_config ALTER COLUMN {column} DROP DEFAULT"))

    _run_migration(conn)
    conn.execute(text("INSERT INTO app_config (platform) VALUES ('ios')"))

    row = conn.execute(
        text("SELECT min_version, latest_version, feature_flags FROM app_config WHERE platform = 'ios'")
    ).one()
    assert (row.min_version, row.latest_version, row.feature_flags) == ("0.0.0", "0.0.0", {})


def test_migration_091_is_idempotent_and_keeps_existing_values(conn):
    """Rodar de novo não duplica nem sobrescreve o que o admin já configurou."""
    conn.execute(text("DELETE FROM app_config"))
    conn.execute(
        text("INSERT INTO app_config (platform, min_version, latest_version) VALUES ('android', '1.3.0', '1.4.0')")
    )

    _run_migration(conn)
    _run_migration(conn)

    rows = conn.execute(text("SELECT min_version, latest_version FROM app_config WHERE platform = 'android'")).all()
    assert [(r.min_version, r.latest_version) for r in rows] == [("1.3.0", "1.4.0")]


def test_migration_091_adds_user_app_version_columns(conn):
    conn.execute(text("ALTER TABLE users DROP COLUMN IF EXISTS last_app_version"))
    conn.execute(text("ALTER TABLE users DROP COLUMN IF EXISTS last_app_platform"))
    conn.execute(text("ALTER TABLE users DROP COLUMN IF EXISTS last_app_seen_at"))

    _run_migration(conn)

    columns = {
        r[0]
        for r in conn.execute(
            text(
                "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name LIKE 'last_app_%'"
            )
        )
    }
    assert columns == {"last_app_version", "last_app_platform", "last_app_seen_at"}


def test_model_created_table_has_database_defaults(conn):
    """O modelo (create_all) já cria a tabela com os padrões do banco."""
    conn.execute(text("DELETE FROM app_config"))
    conn.execute(text("INSERT INTO app_config (platform) VALUES ('ios')"))
    row = conn.execute(
        text("SELECT min_version, latest_version, feature_flags FROM app_config WHERE platform = 'ios'")
    ).one()
    assert (row.min_version, row.latest_version, row.feature_flags) == ("0.0.0", "0.0.0", {})


# ─── migration 092 (denúncias e bloqueios) pelo mesmo caminho ───────────────

MIGRATION_092 = Path(__file__).resolve().parent.parent / "migrations" / "092_photo_reports_and_user_blocks.sql"


def _run_migration_092(conn) -> None:
    for statement in _split_statements(MIGRATION_092.read_text(encoding="utf-8")):
        conn.execute(text(statement + ";"))


def test_migration_092_runs_over_tables_created_by_create_all(conn):
    """Em produção o create_all cria as tabelas antes da migration: ela não pode falhar nem duplicar."""
    _run_migration_092(conn)
    _run_migration_092(conn)  # idempotente

    tabelas = {
        r[0]
        for r in conn.execute(
            text(
                "SELECT table_name FROM information_schema.tables WHERE table_name IN ('academy_photo_reports', 'user_blocks')"
            )
        )
    }
    assert tabelas == {"academy_photo_reports", "user_blocks"}


def test_migration_092_restores_defaults_and_keeps_data_when_table_lacks_them(conn):
    """Tabela já existente sem os padrões do banco (cenário do bug da 091)."""
    conn.execute(text("ALTER TABLE academy_photo_reports ALTER COLUMN status DROP DEFAULT"))
    conn.execute(text("ALTER TABLE academy_photo_reports ALTER COLUMN created_at DROP DEFAULT"))
    conn.execute(text("ALTER TABLE user_blocks ALTER COLUMN created_at DROP DEFAULT"))

    _run_migration_092(conn)

    defaults = {
        (r.table_name, r.column_name): r.column_default
        for r in conn.execute(
            text(
                "SELECT table_name, column_name, column_default FROM information_schema.columns "
                "WHERE (table_name = 'academy_photo_reports' AND column_name IN ('status', 'created_at')) "
                "OR (table_name = 'user_blocks' AND column_name = 'created_at')"
            )
        )
    }
    assert "open" in defaults[("academy_photo_reports", "status")]
    assert "now()" in defaults[("academy_photo_reports", "created_at")].lower()
    assert "now()" in defaults[("user_blocks", "created_at")].lower()
