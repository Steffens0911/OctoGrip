-- Reconhecimento facial para chamada por foto (premium por academia).
-- Inclui:
-- - flag de recurso por academia
-- - avatar_url de utilizador (origem para embeddings)
-- - tabela de embeddings por aluno
-- - fila/resultados de jobs de reconhecimento
-- - metadados em attendance_records

BEGIN;

ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS face_recognition_enabled BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS avatar_url TEXT NULL;

CREATE TABLE IF NOT EXISTS student_face_embedding (
  id UUID PRIMARY KEY,
  student_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
  embedding JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_student_face_embedding_academy_id
  ON student_face_embedding (academy_id);

CREATE TABLE IF NOT EXISTS face_recognition_jobs (
  id UUID PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
  created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  photo_path TEXT NOT NULL,
  result_json JSONB NULL,
  error_message TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS ix_face_recognition_jobs_session_id
  ON face_recognition_jobs (session_id);
CREATE INDEX IF NOT EXISTS ix_face_recognition_jobs_academy_id
  ON face_recognition_jobs (academy_id);
CREATE INDEX IF NOT EXISTS ix_face_recognition_jobs_status
  ON face_recognition_jobs (status);
CREATE INDEX IF NOT EXISTS ix_face_recognition_jobs_created_by_user_id
  ON face_recognition_jobs (created_by_user_id);
CREATE INDEX IF NOT EXISTS ix_face_recognition_jobs_completed_at
  ON face_recognition_jobs (completed_at);

ALTER TABLE attendance_records
  ALTER COLUMN method TYPE VARCHAR(32);

ALTER TABLE attendance_records
  ADD COLUMN IF NOT EXISTS face_recognition BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN academies.face_recognition_enabled IS
  'Feature flag premium para chamada por reconhecimento facial.';
COMMENT ON COLUMN users.avatar_url IS
  'URL pública da foto do utilizador usada para gerar embedding facial.';
COMMENT ON COLUMN attendance_records.face_recognition IS
  'True quando a presença foi confirmada via fluxo de reconhecimento facial.';
COMMENT ON TABLE student_face_embedding IS
  'Embedding facial por aluno para comparação nas chamadas por foto.';
COMMENT ON TABLE face_recognition_jobs IS
  'Jobs assíncronos de processamento de foto para reconhecimento facial.';
COMMENT ON COLUMN face_recognition_jobs.status IS
  'pending|processing|completed|failed';

COMMIT;
