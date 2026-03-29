-- Pontos por conclusão de lição (biblioteca), alinhados a MIN_REWARD_POINTS (10).
-- Linhas existentes ficam com 0 (comportamento histórico sem crédito no total).

ALTER TABLE lesson_progress
  ADD COLUMN IF NOT EXISTS points_awarded INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN lesson_progress.points_awarded IS 'Pontos creditados nesta conclusão (soma em total_points).';
