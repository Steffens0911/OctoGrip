-- Fase 2: confirmações antecipadas de presença (pré-checkin)

CREATE TABLE IF NOT EXISTS training_pre_checkins (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    training_session_id  UUID        NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
    user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    academy_id           UUID        NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    status               VARCHAR(16) NOT NULL DEFAULT 'confirmed',
    confirmed_at         TIMESTAMPTZ,
    cancelled_at         TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (training_session_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_pre_checkins_session  ON training_pre_checkins(training_session_id);
CREATE INDEX IF NOT EXISTS ix_pre_checkins_user     ON training_pre_checkins(user_id);
CREATE INDEX IF NOT EXISTS ix_pre_checkins_academy  ON training_pre_checkins(academy_id);
