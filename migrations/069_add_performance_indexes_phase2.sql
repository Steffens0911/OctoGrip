-- 069: Índices adicionais de performance para listagens e painéis.
-- Compatível com schema atual (users / attendance_sessions / attendance_records).
-- Idempotente: CREATE INDEX IF NOT EXISTS.

BEGIN;

-- Presença: filtros recorrentes por academia + status (sessões ativas/encerradas).
CREATE INDEX IF NOT EXISTS ix_attendance_sessions_academy_status
  ON attendance_sessions (academy_id, status);

-- Presença: consultas de histórico por aluno dentro de sessões.
CREATE INDEX IF NOT EXISTS ix_attendance_records_user_session
  ON attendance_records (user_id, session_id);

-- Presença: ordenação temporal por sessão (detalhes/ranking por janela).
CREATE INDEX IF NOT EXISTS ix_attendance_records_session_checked_in_at
  ON attendance_records (session_id, checked_in_at DESC);

-- Alunos: listagens por academia/role com filtro de bloqueio de conta.
CREATE INDEX IF NOT EXISTS ix_users_academy_role_account_frozen
  ON users (academy_id, role, account_frozen);

-- Missões: listagem por academia com soft-delete e ordenação por slot.
CREATE INDEX IF NOT EXISTS ix_missions_academy_deleted_slot
  ON missions (academy_id, deleted_at, slot_index, id DESC);

-- Troféus: listagem por academia de registos ativos com ordenação por nome.
CREATE INDEX IF NOT EXISTS ix_trophies_academy_deleted_name
  ON trophies (academy_id, deleted_at, name);

COMMIT;
