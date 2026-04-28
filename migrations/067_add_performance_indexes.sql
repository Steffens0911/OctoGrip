-- 067: Índices compostos para janelas temporais + escopo de academia (ranking, presença, engajamento).
-- Idempotente: CREATE INDEX IF NOT EXISTS.

BEGIN;

-- Presença: filtros frequentes academy_id + starts_at (ranking, stats, listagem de sessões)
CREATE INDEX IF NOT EXISTS ix_attendance_sessions_academy_starts_at
  ON attendance_sessions (academy_id, starts_at DESC);

-- Presença: sessões criadas por professor em período (stats_sessions_by_professor)
CREATE INDEX IF NOT EXISTS ix_attendance_sessions_created_by_starts_at
  ON attendance_sessions (created_by_user_id, starts_at DESC);

-- Engajamento: alunos por academia com filtro role + last_login_at (métricas / relatórios ativos)
CREATE INDEX IF NOT EXISTS ix_users_academy_role_last_login
  ON users (academy_id, role, last_login_at DESC NULLS LAST)
  WHERE academy_id IS NOT NULL;

-- Histórico de conclusões por aluno (mission_usages/history + agregações por user)
CREATE INDEX IF NOT EXISTS ix_mission_usages_user_completed_at
  ON mission_usages (user_id, completed_at DESC NULLS LAST);

-- Relatório de logins semanal: varre intervalo de login_day antes de user_id
CREATE INDEX IF NOT EXISTS ix_user_login_days_day_user
  ON user_login_days (login_day, user_id);

COMMIT;
