-- Senha para login (hash bcrypt). Nullable para usuários existentes.
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) NULL;
COMMENT ON COLUMN users.password_hash IS 'Hash bcrypt da senha para login.';
