-- App Android/iOS: versão mínima, versão mais recente e feature flags por plataforma
-- (GET /app/config, editável em PUT /admin/app-config/{platform}), e a última versão
-- do app vista por usuário (header X-App-Version), base do ciclo de depreciação da API.
--
-- O bootstrap roda create_all ANTES das migrations: a tabela pode já existir (criada pelo modelo,
-- possivelmente sem os padrões do banco). Por isso: padrões reafirmados e INSERT com todos os valores.

CREATE TABLE IF NOT EXISTS app_config (
    platform        VARCHAR(16) PRIMARY KEY,
    min_version     VARCHAR(32) NOT NULL DEFAULT '0.0.0',
    latest_version  VARCHAR(32) NOT NULL DEFAULT '0.0.0',
    update_message  TEXT,
    store_url       TEXT,
    feature_flags   JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE app_config
    ALTER COLUMN min_version    SET DEFAULT '0.0.0',
    ALTER COLUMN latest_version SET DEFAULT '0.0.0',
    ALTER COLUMN feature_flags  SET DEFAULT '{}'::jsonb,
    ALTER COLUMN updated_at     SET DEFAULT NOW();

INSERT INTO app_config (platform, min_version, latest_version, store_url, feature_flags)
VALUES ('android', '0.0.0', '0.0.0', 'https://play.google.com/store/apps/details?id=br.com.octogrip.app', '{}'::jsonb)
ON CONFLICT (platform) DO NOTHING;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS last_app_version  VARCHAR(32),
    ADD COLUMN IF NOT EXISTS last_app_platform VARCHAR(16),
    ADD COLUMN IF NOT EXISTS last_app_seen_at  TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS ix_users_last_app_seen_at ON users (last_app_seen_at);
