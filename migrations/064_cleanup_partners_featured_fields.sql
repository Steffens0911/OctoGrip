ALTER TABLE partners
  DROP COLUMN IF EXISTS is_featured;

ALTER TABLE partners
  DROP COLUMN IF EXISTS featured_order;

ALTER TABLE partners
  DROP COLUMN IF EXISTS is_active;

ALTER TABLE partners
  DROP COLUMN IF EXISTS offer_text;

ALTER TABLE partners
  DROP COLUMN IF EXISTS external_url;

DROP INDEX IF EXISTS idx_partners_academy_featured_active_order;
