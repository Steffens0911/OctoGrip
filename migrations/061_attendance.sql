-- Chamada / Presença por QR Code (sessões e registros).
-- Sessões: professor/gerente/admin abre uma janela de chamada; alunos fazem check-in por QR.
-- Registros: um registro por aluno por sessão (unique).

BEGIN;

CREATE TABLE IF NOT EXISTS attendance_sessions (
  id UUID PRIMARY KEY,
  academy_id UUID NULL REFERENCES academies(id) ON DELETE SET NULL,
  created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active',
  title TEXT NULL,
  starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at TIMESTAMPTZ NULL,
  expires_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS ix_attendance_sessions_academy_id ON attendance_sessions (academy_id);
CREATE INDEX IF NOT EXISTS ix_attendance_sessions_starts_at ON attendance_sessions (starts_at);
CREATE INDEX IF NOT EXISTS ix_attendance_sessions_status ON attendance_sessions (status);

CREATE TABLE IF NOT EXISTS attendance_records (
  id UUID PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  checked_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  method TEXT NOT NULL DEFAULT 'qr'
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_attendance_records_session_user ON attendance_records (session_id, user_id);
CREATE INDEX IF NOT EXISTS ix_attendance_records_user_id ON attendance_records (user_id);
CREATE INDEX IF NOT EXISTS ix_attendance_records_checked_in_at ON attendance_records (checked_in_at);

COMMENT ON TABLE attendance_sessions IS 'Sessões de chamada (QR) abertas por professor/gestor/admin.';
COMMENT ON COLUMN attendance_sessions.status IS 'active|closed';
COMMENT ON TABLE attendance_records IS 'Presenças registradas via QR (um por aluno por sessão).';

COMMIT;

