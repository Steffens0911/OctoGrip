-- Flag de visibilidade para seção de apoiadores globais na home do aluno.
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS show_global_supporters BOOLEAN NOT NULL DEFAULT TRUE;

