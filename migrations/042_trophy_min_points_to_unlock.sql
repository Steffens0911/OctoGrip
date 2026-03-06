-- Pontos mínimos do aluno para poder ver/competir pelo troféu; 0 = todos.
ALTER TABLE trophies ADD COLUMN IF NOT EXISTS min_points_to_unlock INTEGER NOT NULL DEFAULT 0;
COMMENT ON COLUMN trophies.min_points_to_unlock IS 'Pontos mínimos do aluno para poder ver/competir pelo troféu; 0 = todos.';
