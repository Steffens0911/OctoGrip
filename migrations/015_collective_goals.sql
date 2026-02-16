-- Meta coletiva semanal por técnica (gamificação).
CREATE TABLE IF NOT EXISTS collective_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    academy_id UUID NULL REFERENCES academies(id) ON DELETE CASCADE,
    technique_id UUID NOT NULL REFERENCES techniques(id) ON DELETE CASCADE,
    target_count INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_collective_goals_academy_id ON collective_goals(academy_id);
CREATE INDEX IF NOT EXISTS ix_collective_goals_technique_id ON collective_goals(technique_id);
CREATE INDEX IF NOT EXISTS ix_collective_goals_dates ON collective_goals(start_date, end_date);
COMMENT ON TABLE collective_goals IS 'Meta de execuções da semana (ex.: 100 escape da montada).';
