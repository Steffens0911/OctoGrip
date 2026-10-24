-- Denúncia de conteúdo e bloqueio de usuários no feed de fotos (política de UGC da Google Play).
-- O bootstrap roda create_all ANTES das migrations: as tabelas podem já existir (criadas pelo
-- modelo), então tudo aqui é IF NOT EXISTS e os padrões do banco espelham os do modelo.

CREATE TABLE IF NOT EXISTS academy_photo_reports (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academy_id   UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    reporter_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    photo_id     UUID NOT NULL REFERENCES academy_photos(id) ON DELETE CASCADE,
    comment_id   UUID REFERENCES academy_photo_comments(id) ON DELETE CASCADE,
    reason       VARCHAR(20) NOT NULL,
    details      TEXT,
    status       VARCHAR(20) NOT NULL DEFAULT 'open',
    resolved_by  UUID REFERENCES users(id) ON DELETE SET NULL,
    resolved_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE academy_photo_reports
    ALTER COLUMN status     SET DEFAULT 'open',
    ALTER COLUMN created_at SET DEFAULT NOW(),
    ALTER COLUMN updated_at SET DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS ux_photo_reports_photo
    ON academy_photo_reports (reporter_id, photo_id) WHERE comment_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_photo_reports_comment
    ON academy_photo_reports (reporter_id, comment_id) WHERE comment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_photo_reports_academy_status
    ON academy_photo_reports (academy_id, status, created_at);
CREATE INDEX IF NOT EXISTS ix_academy_photo_reports_reporter_id
    ON academy_photo_reports (reporter_id);

CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT ck_user_blocks_not_self CHECK (blocker_id <> blocked_id)
);

ALTER TABLE user_blocks ALTER COLUMN created_at SET DEFAULT NOW();

CREATE INDEX IF NOT EXISTS ix_user_blocks_blocked_id ON user_blocks (blocked_id);
