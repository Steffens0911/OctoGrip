-- Remover entidade Position e dependências de training_feedback
-- Script idempotente para ambientes já migrados parcialmente.

-- 1) Remover FK e coluna position_id de training_feedback (se existir)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'training_feedback' AND column_name = 'position_id'
    ) THEN
        -- Remover constraint de FK se existir (nome pode variar; usar catálogo)
        PERFORM 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE t.relname = 'training_feedback' AND c.contype = 'f';

        -- Tentar remover quaisquer FKs que referenciem position_id
        FOR
            SELECT conname
            FROM pg_constraint c
            JOIN pg_class t ON t.oid = c.conrelid
            WHERE t.relname = 'training_feedback' AND c.contype = 'f'
        LOOP
            EXECUTE format('ALTER TABLE training_feedback DROP CONSTRAINT IF EXISTS %I;', conname);
        END LOOP;

        -- Remover índice automático (se houver) e a coluna
        ALTER TABLE training_feedback DROP COLUMN IF EXISTS position_id;
    END IF;
END;
$$;

-- 2) Dropar tabela positions, se existir
DROP TABLE IF EXISTS positions CASCADE;

