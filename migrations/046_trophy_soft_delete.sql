-- Soft delete: troféus "removidos" ficam ocultos em listagens e galeria, sem apagar a linha.
ALTER TABLE trophies ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL;
-- Índice parcial: linhas ainda ativas (admin lista só estas)
CREATE INDEX IF NOT EXISTS ix_trophies_active ON trophies(academy_id) WHERE deleted_at IS NULL;
COMMENT ON COLUMN trophies.deleted_at IS 'Preenchido quando o admin remove o troféu (soft delete).';
