-- Flag para permitir/impedir chamada por QR por academia.
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS qr_attendance_enabled BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN academies.qr_attendance_enabled IS
  'Controle da academia: habilita ou bloqueia chamada por QR (quando false, presença só manual).';
