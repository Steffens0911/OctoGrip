-- Imagem de horários da academia exibida na home do aluno.
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS schedule_image_url VARCHAR(512);

