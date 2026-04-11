-- Aviso institucional exibido em modal ao abrir a home (Campo de treinamento), uma vez por sessão.
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS login_notice_title VARCHAR(255) NULL;
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS login_notice_body TEXT NULL;
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS login_notice_url VARCHAR(512) NULL;
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS login_notice_active BOOLEAN NOT NULL DEFAULT FALSE;
