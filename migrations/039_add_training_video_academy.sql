-- Adiciona vínculo opcional de vídeo de treinamento com academia.

ALTER TABLE training_videos
  ADD COLUMN IF NOT EXISTS academy_id UUID NULL REFERENCES academies(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_training_videos_academy_id
  ON training_videos(academy_id);

COMMENT ON COLUMN training_videos.academy_id IS 'NULL = vídeo global (todas academias); preenchido = vídeo local da academia.';

