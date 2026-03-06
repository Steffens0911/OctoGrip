-- Faixa mínima do aluno para poder ver/competir pelo troféu; NULL = sem restrição.
ALTER TABLE trophies ADD COLUMN IF NOT EXISTS min_graduation_to_unlock VARCHAR(32) NULL;
COMMENT ON COLUMN trophies.min_graduation_to_unlock IS 'Faixa mínima (white, blue, purple, brown, black) para desbloquear o troféu; NULL = todos.';
