-- 079: Templates de troféus manuais (campeonatos + troféus livres) e concessões
BEGIN;

-- Templates criados pelo professor/gestor da academia
CREATE TABLE IF NOT EXISTS academy_trophy_templates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academy_id      UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    icon            VARCHAR(128),       -- ex: "medal_gold", "trophy_star"
    color           VARCHAR(32),        -- ex: "#FFD700"
    trophy_type     VARCHAR(32) NOT NULL DEFAULT 'custom',
                                        -- 'championship' | 'custom'
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_academy_trophy_templates_academy
    ON academy_trophy_templates(academy_id) WHERE deleted_at IS NULL;

COMMENT ON COLUMN academy_trophy_templates.trophy_type IS
    'championship = vinculado a evento de campeonato; custom = troféu livre da academia';

-- Eventos de campeonato (só para trophy_type=championship)
CREATE TABLE IF NOT EXISTS academy_championship_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academy_id      UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    location        VARCHAR(255),
    event_date      DATE NOT NULL,
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_championship_events_academy
    ON academy_championship_events(academy_id) WHERE deleted_at IS NULL;

-- Concessões manuais: quem recebeu qual troféu/medalha
CREATE TABLE IF NOT EXISTS academy_trophy_awards (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id             UUID NOT NULL
        REFERENCES academy_trophy_templates(id) ON DELETE CASCADE,
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    awarded_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    awarded_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Campos opcionais para campeonatos
    championship_event_id   UUID
        REFERENCES academy_championship_events(id) ON DELETE SET NULL,
    medal_type              VARCHAR(32),    -- 'gold' | 'silver' | 'bronze' | 'participation'
    note                    TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_trophy_awards_template
    ON academy_trophy_awards(template_id);
CREATE INDEX IF NOT EXISTS idx_trophy_awards_user
    ON academy_trophy_awards(user_id);
CREATE INDEX IF NOT EXISTS idx_trophy_awards_event
    ON academy_trophy_awards(championship_event_id)
    WHERE championship_event_id IS NOT NULL;

COMMENT ON COLUMN academy_trophy_awards.medal_type IS
    'Para campeonatos: gold, silver, bronze, participation. Null para troféus livres.';

COMMIT;
