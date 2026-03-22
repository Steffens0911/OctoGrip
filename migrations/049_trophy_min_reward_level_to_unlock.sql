-- Troféu: desbloqueio por nível (reward_level) em vez de pontos acumulados.
ALTER TABLE trophies ADD COLUMN IF NOT EXISTS min_reward_level_to_unlock INTEGER NOT NULL DEFAULT 0;
COMMENT ON COLUMN trophies.min_reward_level_to_unlock IS 'Nível mínimo (users.reward_level) para desbloquear; 0 = sem requisito.';

ALTER TABLE trophies DROP COLUMN IF EXISTS min_points_to_unlock;
