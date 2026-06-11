-- 083: Índice parcial para as queries de /me/training_stats e rankings.
-- Todas filtram status = 'confirmed' e ordenam/filtram por created_at,
-- então o índice parcial é menor e mais seletivo que um composto puro.
-- Idempotente: CREATE INDEX IF NOT EXISTS.

BEGIN;

CREATE INDEX IF NOT EXISTS ix_technique_executions_user_confirmed_created
  ON technique_executions (user_id, created_at)
  WHERE status = 'confirmed';

COMMIT;
