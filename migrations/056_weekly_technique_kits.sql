-- Kits semanais nomeados (rótulo de turma): 1–5 técnicas por kit; missões por kit com weekly_kit_id.

CREATE TABLE IF NOT EXISTS weekly_technique_kits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    label VARCHAR(255) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_weekly_technique_kits_academy
    ON weekly_technique_kits (academy_id)
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS weekly_kit_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kit_id UUID NOT NULL REFERENCES weekly_technique_kits(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL,
    technique_id UUID NOT NULL REFERENCES techniques(id) ON DELETE RESTRICT,
    multiplier INTEGER NOT NULL DEFAULT 10,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_weekly_kit_items_order CHECK (order_index >= 0 AND order_index < 5),
    CONSTRAINT chk_weekly_kit_items_multiplier CHECK (multiplier >= 10 AND multiplier <= 50),
    CONSTRAINT uq_weekly_kit_items_kit_order UNIQUE (kit_id, order_index)
);

CREATE INDEX IF NOT EXISTS idx_weekly_kit_items_kit ON weekly_kit_items (kit_id);

CREATE TABLE IF NOT EXISTS user_weekly_kit_choices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    iso_week_year INTEGER NOT NULL,
    iso_week_number INTEGER NOT NULL,
    kit_id UUID NOT NULL REFERENCES weekly_technique_kits(id) ON DELETE RESTRICT,
    chosen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_weekly_kit_choice UNIQUE (user_id, academy_id, iso_week_year, iso_week_number),
    CONSTRAINT chk_iso_week_number CHECK (iso_week_number >= 1 AND iso_week_number <= 53)
);

CREATE INDEX IF NOT EXISTS idx_user_weekly_kit_choices_user_academy
    ON user_weekly_kit_choices (user_id, academy_id);

ALTER TABLE missions ADD COLUMN IF NOT EXISTS weekly_kit_id UUID NULL
    REFERENCES weekly_technique_kits(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_missions_weekly_kit
    ON missions (academy_id, level, weekly_kit_id, slot_index)
    WHERE deleted_at IS NULL AND weekly_kit_id IS NOT NULL;
