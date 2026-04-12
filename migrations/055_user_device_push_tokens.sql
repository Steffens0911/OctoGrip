-- Tokens FCM por utilizador (vários dispositivos: um token por linha; token único global).
CREATE TABLE IF NOT EXISTS user_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(16) NOT NULL DEFAULT 'android',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_device_tokens_fcm UNIQUE (fcm_token)
);

CREATE INDEX IF NOT EXISTS ix_user_device_tokens_user_id ON user_device_tokens(user_id);

COMMENT ON TABLE user_device_tokens IS 'Tokens Firebase Cloud Messaging para notificações push por dispositivo.';
