-- Tema da semana por academia = técnica selecionada (missão do dia para todos os alunos).
ALTER TABLE academies ADD COLUMN IF NOT EXISTS weekly_technique_id UUID REFERENCES techniques(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS ix_academies_weekly_technique_id ON academies(weekly_technique_id);
COMMENT ON COLUMN academies.weekly_technique_id IS 'Técnica selecionada como missão do dia da semana para os alunos da academia.';
