-- 084: registros de consentimento LGPD (append-only)
-- Cada concessão/revogação é uma linha nova; o estado atual de (user, tipo) é a linha
-- mais recente. Mantém trilha de auditoria imutável para comprovação perante a ANPD.
CREATE TABLE IF NOT EXISTS user_consents (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_type     VARCHAR(32) NOT NULL,
    granted          BOOLEAN NOT NULL,
    document_version VARCHAR(64),
    ip_address       VARCHAR(64),
    user_agent       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_consents_user_id ON user_consents (user_id);
CREATE INDEX IF NOT EXISTS idx_user_consents_user_type ON user_consents (user_id, consent_type, created_at DESC);
