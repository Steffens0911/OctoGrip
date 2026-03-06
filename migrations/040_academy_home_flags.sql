-- Flags de visibilidade de seções na home do aluno.
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS show_trophies BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS show_partners BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS show_schedule BOOLEAN NOT NULL DEFAULT TRUE;

