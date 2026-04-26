-- Adds fields required for "featured partners" banner on Central.
-- Safe to re-run: uses IF NOT EXISTS guards.

ALTER TABLE partners
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE partners
  ADD COLUMN IF NOT EXISTS featured_order INTEGER NULL;

ALTER TABLE partners
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE partners
  ADD COLUMN IF NOT EXISTS offer_text TEXT NULL;

ALTER TABLE partners
  ADD COLUMN IF NOT EXISTS external_url VARCHAR(512) NULL;

-- Indexes to speed up featured listing (academy-scoped).
CREATE INDEX IF NOT EXISTS idx_partners_academy_featured_active_order
  ON partners (academy_id, featured_order)
  WHERE is_featured = true AND is_active = true;

