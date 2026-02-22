-- Medalhas (ordinárias) e troféus (especiais, duração mínima configurável).
ALTER TABLE trophies
  ADD COLUMN IF NOT EXISTS award_kind VARCHAR(32) NOT NULL DEFAULT 'trophy',
  ADD COLUMN IF NOT EXISTS min_duration_days INTEGER NULL;
COMMENT ON COLUMN trophies.award_kind IS 'medal = premiação ordinária; trophy = premiação especial (longo prazo).';
COMMENT ON COLUMN trophies.min_duration_days IS 'Duração mínima em dias quando award_kind = trophy (ex: 30 = 1 mês).';
CREATE INDEX IF NOT EXISTS ix_trophies_award_kind ON trophies(award_kind);
