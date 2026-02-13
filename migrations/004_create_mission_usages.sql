-- Migration: tabela mission_usages para sync do app (PB-01).
-- Executar após 003_add_mission_theme.sql

CREATE TABLE IF NOT EXISTS mission_usages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    opened_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL,
    usage_type VARCHAR(32) NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_mission_usages_user_id ON mission_usages(user_id);
CREATE INDEX IF NOT EXISTS ix_mission_usages_lesson_id ON mission_usages(lesson_id);
CREATE INDEX IF NOT EXISTS ix_mission_usages_completed_at ON mission_usages(completed_at DESC);

COMMENT ON TABLE mission_usages IS 'Uso de missão (before_training/after_training) sincronizado pelo app.';
COMMENT ON COLUMN mission_usages.usage_type IS 'before_training | after_training';
