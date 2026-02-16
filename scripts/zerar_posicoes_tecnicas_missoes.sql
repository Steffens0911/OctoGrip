-- Script manual: zera tabelas de posições, técnicas, lições e missões (e dependentes).
-- Preserva academies e users (apenas zera as FKs em academies).
-- Não é aplicado no startup da API.
--
-- Uso (PowerShell):
--   Get-Content scripts/zerar_posicoes_tecnicas_missoes.sql | docker compose exec -T postgres psql -U jjb -d jjb_db

TRUNCATE technique_executions CASCADE;
TRUNCATE mission_usages CASCADE;
TRUNCATE lesson_progress CASCADE;
TRUNCATE missions CASCADE;
TRUNCATE collective_goals CASCADE;
TRUNCATE lessons CASCADE;

UPDATE academies SET
  weekly_technique_id = NULL,
  weekly_technique_2_id = NULL,
  weekly_technique_3_id = NULL,
  visible_lesson_id = NULL;

-- Sem CASCADE para não truncar academies/users que referenciam techniques/positions
TRUNCATE techniques RESTRICT;
TRUNCATE training_feedback CASCADE;
TRUNCATE positions RESTRICT;
