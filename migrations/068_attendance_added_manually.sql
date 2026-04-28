-- Presença manual explícita (UI professor) vs QR/face automáticos.
ALTER TABLE attendance_records
  ADD COLUMN IF NOT EXISTS added_manually BOOLEAN NOT NULL DEFAULT false;

UPDATE attendance_records SET added_manually = true WHERE method = 'manual';
