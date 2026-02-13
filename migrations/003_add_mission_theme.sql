-- Migration: adiciona tema da semana à tabela missions (PF-02).
-- Executar após 002_add_mission_level.sql

ALTER TABLE missions
ADD COLUMN IF NOT EXISTS theme VARCHAR(128) NULL;

COMMENT ON COLUMN missions.theme IS 'Tema da semana (ex.: Passagem de guarda, Escapes).';