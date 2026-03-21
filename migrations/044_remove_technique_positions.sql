-- Remove relacionamento de técnicas com posições (from_position_id / to_position_id)
-- Este script é tolerante: em bancos que nunca tiveram essas colunas, os ALTER TABLE
-- simplesmente serão ignorados graças ao IF EXISTS.

-- 1) Zerar referências existentes (se as colunas existirem)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'techniques' AND column_name = 'from_position_id'
    ) THEN
        UPDATE techniques SET from_position_id = NULL;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'techniques' AND column_name = 'to_position_id'
    ) THEN
        UPDATE techniques SET to_position_id = NULL;
    END IF;
END;
$$;

-- 2) Remover colunas se existirem (compatível com ambientes já sem essas colunas)
ALTER TABLE techniques DROP COLUMN IF EXISTS from_position_id;
ALTER TABLE techniques DROP COLUMN IF EXISTS to_position_id;


