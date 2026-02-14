-- Migration: cria tabela missions (entrega diária: período + lesson)
-- Executar: psql $DATABASE_URL -f migrations/001_create_missions.sql
-- Ou via Docker: docker compose exec postgres psql -U jjb -d jjb_db -f /migrations/001_create_missions.sql
-- (montar pasta migrations no container se necessário)

CREATE TABLE IF NOT EXISTS missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice lesson_id removido: migração 009 troca missions por technique_id
CREATE INDEX IF NOT EXISTS ix_missions_start_date ON missions(start_date);
CREATE INDEX IF NOT EXISTS ix_missions_end_date ON missions(end_date);
CREATE INDEX IF NOT EXISTS ix_missions_is_active ON missions(is_active);

COMMENT ON TABLE missions IS 'Entrega diária: vincula uma Lesson a um período (start_date..end_date).';
