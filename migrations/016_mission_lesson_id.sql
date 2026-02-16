-- Missão passa a referenciar uma lição específica (missão = mesma coisa que a lição).
ALTER TABLE missions ADD COLUMN IF NOT EXISTS lesson_id UUID NULL REFERENCES lessons(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS ix_missions_lesson_id ON missions(lesson_id);
COMMENT ON COLUMN missions.lesson_id IS 'Lição da missão; quando preenchido, a missão exibe esta lição (título, vídeo, conteúdo).';

-- Preencher lesson_id nas missões existentes com a primeira lição da técnica (por order_index).
UPDATE missions m
SET lesson_id = (
  SELECT l.id FROM lessons l
  WHERE l.technique_id = m.technique_id
  ORDER BY l.order_index ASC
  LIMIT 1
)
WHERE m.lesson_id IS NULL;
