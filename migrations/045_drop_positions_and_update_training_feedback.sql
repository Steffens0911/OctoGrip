-- Remover entidade Position e dependências de training_feedback
-- Script idempotente para ambientes já migrados parcialmente.

-- 1) Remover coluna position_id de training_feedback (se existir).
-- CASCADE remove FKs/índices que dependem da coluna (evita loop PL/pgSQL frágil).
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'training_feedback'
          AND column_name = 'position_id'
    ) THEN
        ALTER TABLE training_feedback DROP COLUMN IF EXISTS position_id CASCADE;
    END IF;
END;
$$;

-- 2) Dropar tabela positions, se existir
DROP TABLE IF EXISTS positions CASCADE;
