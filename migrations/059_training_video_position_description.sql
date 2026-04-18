-- Descrição opcional da posição (contexto do vídeo de treinamento).
ALTER TABLE training_videos
  ADD COLUMN IF NOT EXISTS position_description TEXT NULL;
