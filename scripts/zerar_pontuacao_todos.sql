-- Zera a pontuação de todos os usuários.
-- Não remove registros; apenas define pontos como 0 para que o total exibido seja zero.
-- Uso (PowerShell): Get-Content scripts/zerar_pontuacao_todos.sql | docker compose exec -T postgres psql -U jjb -d jjb_db

UPDATE technique_executions SET points_awarded = 0 WHERE points_awarded IS NOT NULL;
UPDATE mission_usages SET points_awarded = 0 WHERE points_awarded IS NOT NULL;
UPDATE users SET points_adjustment = 0 WHERE points_adjustment != 0;
