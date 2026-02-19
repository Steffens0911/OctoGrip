-- Troféus por academia: técnica, período e meta de execuções; tiers ouro/prata/bronze pela faixa do adversário.
CREATE TABLE IF NOT EXISTS trophies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    technique_id UUID NOT NULL REFERENCES techniques(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    target_count INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_trophies_academy_id ON trophies(academy_id);
CREATE INDEX IF NOT EXISTS ix_trophies_technique_id ON trophies(technique_id);
CREATE INDEX IF NOT EXISTS ix_trophies_name ON trophies(name);
COMMENT ON TABLE trophies IS 'Troféu da academia: meta de execuções da técnica no período; tier por faixa do adversário (ouro/prata/bronze).';
