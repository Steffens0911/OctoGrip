-- Migration: academias e vínculo usuário (A-01).
-- Executar após 004_create_mission_usages.sql

CREATE TABLE IF NOT EXISTS academies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE
);

CREATE INDEX IF NOT EXISTS ix_academies_name ON academies(name);
CREATE INDEX IF NOT EXISTS ix_academies_slug ON academies(slug);

ALTER TABLE users
ADD COLUMN IF NOT EXISTS academy_id UUID REFERENCES academies(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_users_academy_id ON users(academy_id);

COMMENT ON TABLE academies IS 'Academia (B2B): usuário vinculado (A-01).';
COMMENT ON COLUMN users.academy_id IS 'Academia do usuário; NULL = sem academia.';
