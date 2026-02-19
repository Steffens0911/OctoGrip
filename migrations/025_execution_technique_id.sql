-- Execução pode ser por técnica (troféu), sem lição nem missão.
ALTER TABLE technique_executions ADD COLUMN IF NOT EXISTS technique_id UUID NULL REFERENCES techniques(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS ix_technique_executions_technique_id ON technique_executions(technique_id);
COMMENT ON COLUMN technique_executions.technique_id IS 'Quando preenchido, execução é por técnica (ex.: indicar adversário no troféu); exatamente um de mission_id, lesson_id ou technique_id.';

-- Remover constraint antigo e adicionar novo que aceita technique_id
ALTER TABLE technique_executions DROP CONSTRAINT IF EXISTS chk_execution_mission_or_lesson;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_execution_source' AND conrelid = 'technique_executions'::regclass
  ) THEN
    ALTER TABLE technique_executions ADD CONSTRAINT chk_execution_source
      CHECK (
        (mission_id IS NOT NULL AND lesson_id IS NULL AND technique_id IS NULL) OR
        (mission_id IS NULL AND lesson_id IS NOT NULL AND technique_id IS NULL) OR
        (mission_id IS NULL AND lesson_id IS NULL AND technique_id IS NOT NULL)
      );
  END IF;
END $$;
