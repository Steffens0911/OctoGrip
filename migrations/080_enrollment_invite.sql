-- Migration 080: convite de auto-cadastro e fila de aprovação de alunos

CREATE TABLE enrollment_invites (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academy_id  UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    token       VARCHAR(64) NOT NULL UNIQUE,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_enrollment_invites_academy_id ON enrollment_invites (academy_id);
CREATE INDEX ix_enrollment_invites_token      ON enrollment_invites (token);

CREATE TABLE pending_enrollments (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invite_id        UUID NOT NULL REFERENCES enrollment_invites(id) ON DELETE CASCADE,
    academy_id       UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    name             VARCHAR(255) NOT NULL,
    email            VARCHAR(255) NOT NULL,
    phone            VARCHAR(32),
    graduation       VARCHAR(32),
    password_hash    VARCHAR(255) NOT NULL,
    status           VARCHAR(16) NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_pending_enrollments_academy_id ON pending_enrollments (academy_id);
CREATE INDEX ix_pending_enrollments_email      ON pending_enrollments (email);
CREATE INDEX ix_pending_enrollments_status     ON pending_enrollments (status);
