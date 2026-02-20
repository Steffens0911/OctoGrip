-- Adicionar índice composto para otimizar get_points_log que ordena por confirmed_at
-- Este índice melhora a performance de queries que filtram por user_id, status e ordenam por confirmed_at
CREATE INDEX IF NOT EXISTS idx_technique_execution_user_status_confirmed 
ON technique_executions(user_id, status, confirmed_at DESC NULLS LAST);
