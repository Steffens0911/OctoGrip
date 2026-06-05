-- OctoPhotos: feed de fotos por academia (feature premium).
-- Inclui:
--   - flag de feature por academia (octophotos_enabled)
--   - tabela de posts com suporte a upload assíncrono (status)
--   - curtidas com contador desnormalizado (likes_count)
--   - restrições de postagem por aluno

BEGIN;

-- Feature flag por academia (mesmo padrão do face_recognition_enabled)
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS octophotos_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- Posts de foto
CREATE TABLE IF NOT EXISTS academy_photos (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  academy_id          UUID        NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
  author_id           UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  image_url           TEXT,                         -- preenchido pela task Celery após resize
  thumbnail_url       TEXT,                         -- 400×300, preenchido pela task Celery
  raw_file_path       TEXT,                         -- path local do arquivo bruto (app_media/) para a task
  caption             TEXT,
  status              VARCHAR(20) NOT NULL DEFAULT 'processing', -- 'processing' | 'ready' | 'failed'
  likes_count         INTEGER     NOT NULL DEFAULT 0,
  is_system_post      BOOLEAN     NOT NULL DEFAULT FALSE,
  system_post_type    VARCHAR(50),                  -- 'belt_promotion' | 'trophy' | 'level_up'
  system_post_ref_id  UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ                   -- soft delete
);

-- Feed paginado filtrado por academia + posts ativos, ordem cronológica inversa
CREATE INDEX IF NOT EXISTS ix_academy_photos_feed
  ON academy_photos (academy_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_academy_photos_author_id
  ON academy_photos (author_id);

-- Status para a task Celery localizar posts pendentes
CREATE INDEX IF NOT EXISTS ix_academy_photos_status
  ON academy_photos (status)
  WHERE deleted_at IS NULL;

-- Curtidas (PK composta garante unicidade; likes_count atualizado na aplicação)
CREATE TABLE IF NOT EXISTS academy_photo_likes (
  photo_id    UUID        NOT NULL REFERENCES academy_photos(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (photo_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_academy_photo_likes_user_id
  ON academy_photo_likes (user_id);

-- Restrições de postagem (aluno pode ler o feed mas não postar)
CREATE TABLE IF NOT EXISTS academy_photo_restrictions (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  academy_id      UUID        NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
  user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restricted_by   UUID        NOT NULL REFERENCES users(id),
  reason          TEXT,
  expires_at      TIMESTAMPTZ,          -- NULL = permanente
  active          BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Apenas uma restrição ativa por (academia, aluno) — partial index evita o bug
-- do UNIQUE(academy_id, user_id, active) que limita a um histórico por aluno
CREATE UNIQUE INDEX IF NOT EXISTS ix_photo_restrictions_active_unique
  ON academy_photo_restrictions (academy_id, user_id)
  WHERE active = TRUE;

CREATE INDEX IF NOT EXISTS ix_photo_restrictions_academy_id
  ON academy_photo_restrictions (academy_id);

CREATE INDEX IF NOT EXISTS ix_photo_restrictions_user_id
  ON academy_photo_restrictions (user_id);

-- Usado para expirar restrições temporárias via Celery beat
CREATE INDEX IF NOT EXISTS ix_photo_restrictions_expires_at
  ON academy_photo_restrictions (expires_at)
  WHERE active = TRUE AND expires_at IS NOT NULL;

COMMENT ON COLUMN academies.octophotos_enabled
  IS 'Feature flag premium para o feed de fotos OctoPhotos.';
COMMENT ON COLUMN academy_photos.status
  IS 'processing = upload recebido, aguardando resize Celery; ready = pronto para exibição; failed = erro no processamento.';
COMMENT ON COLUMN academy_photos.raw_file_path
  IS 'Path local em app_media/ do arquivo bruto antes do resize. Limpo pela task Celery após processamento.';
COMMENT ON COLUMN academy_photos.likes_count
  IS 'Contador desnormalizado atualizado atomicamente na aplicação (UPDATE ... SET likes_count = likes_count ± 1).';

COMMIT;
