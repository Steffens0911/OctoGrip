-- Migration: adiciona nível (beginner/intermediate) à tabela missions (PF-01).
-- Executar após 001_create_missions.sql

ALTER TABLE missions
ADD COLUMN IF NOT EXISTS level VARCHAR(32) NOT NULL DEFAULT 'beginner';

CREATE INDEX IF NOT EXISTS ix_missions_level ON missions(level);

COMMENT ON COLUMN missions.level IS 'Nível da missão: beginner ou intermediate.';
