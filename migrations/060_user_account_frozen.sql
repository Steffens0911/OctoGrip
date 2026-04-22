-- Conta congelada manualmente (gestor/admin); alunos em modo leitura na API mutável.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS account_frozen BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS account_freeze_reason TEXT NULL;

CREATE INDEX IF NOT EXISTS ix_users_account_frozen ON users (account_frozen);

COMMENT ON COLUMN users.account_frozen IS 'Se true (e role=aluno), bloqueia POST/PUT/PATCH/DELETE relevantes; login permitido.';
COMMENT ON COLUMN users.account_freeze_reason IS 'Motivo opcional para o aluno (UI).';
