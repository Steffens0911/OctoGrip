-- Migration 077: tabela de comentários em fotos
CREATE TABLE IF NOT EXISTS academy_photo_comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id    UUID NOT NULL REFERENCES academy_photos(id) ON DELETE CASCADE,
    author_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body        TEXT NOT NULL,
    deleted_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_photo_comments_photo ON academy_photo_comments(photo_id, created_at)
    WHERE deleted_at IS NULL;

-- Contador desnormalizado na tabela pai
ALTER TABLE academy_photos ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0;
