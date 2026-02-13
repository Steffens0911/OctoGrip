-- Migration: tema semanal definido pelo professor (A-03).
-- Executar após 006_add_mission_academy.sql

ALTER TABLE academies
ADD COLUMN IF NOT EXISTS weekly_theme VARCHAR(128) NULL;

COMMENT ON COLUMN academies.weekly_theme IS 'A-03: tema semanal definido pelo professor; usado na missão do dia.';
