ALTER TABLE global_partners
  ADD COLUMN IF NOT EXISTS button_label VARCHAR(18);

ALTER TABLE partners
  ADD COLUMN IF NOT EXISTS button_label VARCHAR(18);
