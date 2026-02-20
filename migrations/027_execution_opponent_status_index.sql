-- Índice composto para acelerar count e listagem de confirmações pendentes.
-- WHERE opponent_id = ? AND status = 'pending_confirmation'
-- Nota: Nome alinhado com o modelo (idx_technique_execution_opponent_status)
CREATE INDEX IF NOT EXISTS idx_technique_execution_opponent_status ON technique_executions(opponent_id, status);
