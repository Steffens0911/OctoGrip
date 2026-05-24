-- Tabela de notificações in-app por usuário
CREATE TABLE IF NOT EXISTS notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(50) NOT NULL,
    title       VARCHAR(200) NOT NULL,
    body        TEXT NOT NULL,
    read        BOOLEAN NOT NULL DEFAULT FALSE,
    data        JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_notifications_user_id  ON notifications (user_id);
CREATE INDEX IF NOT EXISTS ix_notifications_type     ON notifications (type);
CREATE INDEX IF NOT EXISTS ix_notifications_read     ON notifications (read);
CREATE INDEX IF NOT EXISTS ix_notifications_user_read ON notifications (user_id, read);
