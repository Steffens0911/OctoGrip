-- Registra troféus/medalhas conquistados por usuário (persiste tier e momento da conquista).
-- Unique em (user_id, trophy_id): INSERT ... ON CONFLICT faz upsert quando tier sobe.
CREATE TABLE IF NOT EXISTS user_trophy_earned (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trophy_id   UUID NOT NULL REFERENCES trophies(id) ON DELETE CASCADE,
    tier        VARCHAR(10) NOT NULL,          -- 'bronze', 'silver', 'gold'
    earned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT user_trophy_earned_unique UNIQUE (user_id, trophy_id)
);

CREATE INDEX IF NOT EXISTS idx_user_trophy_earned_user  ON user_trophy_earned (user_id);
CREATE INDEX IF NOT EXISTS idx_user_trophy_earned_trophy ON user_trophy_earned (trophy_id);
