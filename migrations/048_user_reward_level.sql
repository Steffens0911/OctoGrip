-- Sistema de níveis (reward_level) baseado no total de pontos do usuário.
-- Nível 1: threshold de 50 pontos; crescimento de 20% por nível.

ALTER TABLE users ADD COLUMN IF NOT EXISTS reward_level INTEGER NOT NULL DEFAULT 1;
ALTER TABLE users ADD COLUMN IF NOT EXISTS reward_level_points INTEGER NOT NULL DEFAULT 0;

