-- Execução pode ser por lição (sem missão): mesmo fluxo de adversário e confirmação.
ALTER TABLE technique_executions ADD COLUMN IF NOT EXISTS lesson_id UUID NULL REFERENCES lessons(id) ON DELETE CASCADE;
ALTER TABLE technique_executions ALTER COLUMN mission_id DROP NOT NULL;
CREATE INDEX IF NOT EXISTS ix_technique_executions_lesson_id ON technique_executions(lesson_id);
COMMENT ON COLUMN technique_executions.lesson_id IS 'Quando preenchido, execução é por lição (sem missão ativa).';
COMMENT ON COLUMN technique_executions.mission_id IS 'Quando preenchido, execução é por missão do dia; um de mission_id ou lesson_id deve estar preenchido.';
-- Garantir que pelo menos um de mission_id ou lesson_id está preenchido (idempotente).
-- Só adiciona se a constraint nova (chk_execution_source, da migração 025) ainda não existir,
-- para não violar linhas que tenham technique_id preenchido.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_execution_source' AND conrelid = 'technique_executions'::regclass
  )
  AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_execution_mission_or_lesson' AND conrelid = 'technique_executions'::regclass
  ) THEN
    ALTER TABLE technique_executions ADD CONSTRAINT chk_execution_mission_or_lesson
      CHECK (
        (mission_id IS NOT NULL AND lesson_id IS NULL) OR
        (mission_id IS NULL AND lesson_id IS NOT NULL)
      );
  END IF;
END $$;
