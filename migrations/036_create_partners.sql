-- Parceiros por academia: divulgação para alunos (nome, descrição, link, logo).
CREATE TABLE IF NOT EXISTS partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    url VARCHAR(512),
    logo_url VARCHAR(512)
);
CREATE INDEX IF NOT EXISTS ix_partners_academy_id ON partners(academy_id);
COMMENT ON TABLE partners IS 'Parceiros da academia para divulgação aos alunos (empresas, academias, etc.).';
