-- Três missões semanais: segunda coluna = slot 2 (qua-qui), terceira = slot 3 (sex-dom).
ALTER TABLE academies ADD COLUMN IF NOT EXISTS weekly_technique_2_id UUID REFERENCES techniques(id) ON DELETE SET NULL;
ALTER TABLE academies ADD COLUMN IF NOT EXISTS weekly_technique_3_id UUID REFERENCES techniques(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS ix_academies_weekly_technique_2_id ON academies(weekly_technique_2_id);
CREATE INDEX IF NOT EXISTS ix_academies_weekly_technique_3_id ON academies(weekly_technique_3_id);
COMMENT ON COLUMN academies.weekly_technique_2_id IS 'Técnica da missão semanal slot 2 (qua-qui).';
COMMENT ON COLUMN academies.weekly_technique_3_id IS 'Técnica da missão semanal slot 3 (sex-dom).';
