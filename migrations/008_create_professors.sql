-- Migration: tabela professors (seção professor).
-- Executar após 007_add_academy_weekly_theme.sql

CREATE TABLE IF NOT EXISTS professors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    academy_id UUID REFERENCES academies(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_professors_name ON professors(name);
CREATE INDEX IF NOT EXISTS ix_professors_email ON professors(email);
CREATE INDEX IF NOT EXISTS ix_professors_academy_id ON professors(academy_id);

COMMENT ON TABLE professors IS 'Professor vinculado a academia (área do professor: missões, tema, ranking).';
