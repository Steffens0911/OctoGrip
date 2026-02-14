-- Migration: Missão por técnica (em vez de lição) e conclusão por missão.
-- 1) missions: lesson_id -> technique_id
-- 2) mission_usages: mission_id (opcional), lesson_id passa a ser opcional

-- missions: adicionar technique_id
ALTER TABLE missions ADD COLUMN IF NOT EXISTS technique_id UUID REFERENCES techniques(id) ON DELETE RESTRICT;

-- Preencher technique_id a partir da lição atual só se a coluna lesson_id ainda existir (idempotente)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'missions' AND column_name = 'lesson_id') THEN
    UPDATE missions
    SET technique_id = (SELECT technique_id FROM lessons WHERE lessons.id = missions.lesson_id)
    WHERE missions.lesson_id IS NOT NULL AND (missions.technique_id IS NULL);
    UPDATE missions
    SET technique_id = (SELECT id FROM techniques LIMIT 1)
    WHERE missions.technique_id IS NULL;
  END IF;
END $$;

-- Remover lesson_id
ALTER TABLE missions DROP CONSTRAINT IF EXISTS missions_lesson_id_fkey;
DROP INDEX IF EXISTS ix_missions_lesson_id;
ALTER TABLE missions DROP COLUMN IF EXISTS lesson_id;

ALTER TABLE missions ALTER COLUMN technique_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS ix_missions_technique_id ON missions(technique_id);

COMMENT ON COLUMN missions.technique_id IS 'Técnica da missão do dia (posição de → para).';

-- mission_usages: adicionar mission_id (conclusão por missão)
ALTER TABLE mission_usages ADD COLUMN IF NOT EXISTS mission_id UUID REFERENCES missions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS ix_mission_usages_mission_id ON mission_usages(mission_id);

-- lesson_id em mission_usages passa a opcional (legado; novas conclusões usam mission_id)
ALTER TABLE mission_usages ALTER COLUMN lesson_id DROP NOT NULL;

COMMENT ON COLUMN mission_usages.mission_id IS 'Missão concluída (conclusão por missão). Preenchido nas novas conclusões.';
