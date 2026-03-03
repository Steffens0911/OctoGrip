-- Timestamp do último login bem-sucedido do usuário.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ NULL;
COMMENT ON COLUMN users.last_login_at IS 'Data/hora do último login bem-sucedido (para métricas de engajamento).';

