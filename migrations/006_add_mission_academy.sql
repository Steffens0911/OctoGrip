-- Migration: missão por academia — override global (A-02).
-- Executar após 005_create_academies_and_user_link.sql

ALTER TABLE missions
ADD COLUMN IF NOT EXISTS academy_id UUID REFERENCES academies(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_missions_academy_id ON missions(academy_id);

COMMENT ON COLUMN missions.academy_id IS 'NULL = missão global; preenchido = override da academia (A-02).';
