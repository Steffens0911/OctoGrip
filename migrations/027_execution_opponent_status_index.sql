-- Índice composto para acelerar count e listagem de confirmações pendentes.
-- WHERE opponent_id = ? AND status = 'pending_confirmation'
CREATE INDEX IF NOT EXISTS ix_technique_executions_opponent_status ON technique_executions(opponent_id, status);
