-- 082: adiciona updated_at em password_reset_tokens (herdada do UUIDMixin)
ALTER TABLE password_reset_tokens
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
