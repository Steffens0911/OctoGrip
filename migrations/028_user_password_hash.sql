-- Senha para login (hash pbkdf2_sha256). Nullable para usuários existentes.
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) NULL;
COMMENT ON COLUMN users.password_hash IS 'Hash pbkdf2_sha256 da senha para login.';
