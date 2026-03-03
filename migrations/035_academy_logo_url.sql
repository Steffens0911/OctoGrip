-- Logo / brasão da academia exibido no app dos alunos.
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS logo_url VARCHAR(512);

