-- Fase 1: treinos lançados pelo professor e templates (favoritos)

CREATE TABLE IF NOT EXISTS training_templates (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    academy_id          UUID        NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    created_by_user_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
    label               VARCHAR(128),
    start_time          VARCHAR(5)  NOT NULL,
    tolerance_minutes   INTEGER     NOT NULL DEFAULT 15,
    sort_order          INTEGER     NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_training_templates_academy_id ON training_templates(academy_id);

CREATE TABLE IF NOT EXISTS training_sessions (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    academy_id          UUID        NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    created_by_user_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
    template_id         UUID        REFERENCES training_templates(id) ON DELETE SET NULL,
    class_date          DATE        NOT NULL,
    start_time          VARCHAR(5)  NOT NULL,
    tolerance_minutes   INTEGER     NOT NULL DEFAULT 15,
    label               VARCHAR(128),
    status              VARCHAR(16) NOT NULL DEFAULT 'upcoming',
    opened_at           TIMESTAMPTZ,
    closed_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_training_sessions_academy_date ON training_sessions(academy_id, class_date);
CREATE INDEX IF NOT EXISTS ix_training_sessions_status        ON training_sessions(status);
