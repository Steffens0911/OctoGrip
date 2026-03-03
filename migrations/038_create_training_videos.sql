-- Vídeos de treinamento (campo de treinamento) e visualizações diárias.

CREATE TABLE IF NOT EXISTS training_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    title VARCHAR(255) NOT NULL,
    youtube_url VARCHAR(512) NOT NULL,
    points_per_day INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    order_index INTEGER,
    duration_seconds INTEGER,
    created_by_id UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_training_videos_is_active ON training_videos(is_active);
CREATE INDEX IF NOT EXISTS ix_training_videos_order_index ON training_videos(order_index);
CREATE INDEX IF NOT EXISTS ix_training_videos_created_by_id ON training_videos(created_by_id);

COMMENT ON TABLE training_videos IS 'Vídeos de treinamento voluntário (campo de treinamento), com pontuação diária.';
COMMENT ON COLUMN training_videos.youtube_url IS 'URL do vídeo no YouTube.';


CREATE TABLE IF NOT EXISTS training_video_daily_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    training_video_id UUID NOT NULL REFERENCES training_videos(id) ON DELETE CASCADE,
    view_date DATE NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL,
    points_awarded INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE training_video_daily_views
    ADD CONSTRAINT uq_training_video_daily_view_unique
    UNIQUE (user_id, training_video_id, view_date);

CREATE INDEX IF NOT EXISTS ix_training_video_daily_views_user_date
    ON training_video_daily_views(user_id, view_date);

COMMENT ON TABLE training_video_daily_views IS 'Visualizações diárias de vídeos de treinamento (1 linha por usuário, vídeo e dia).';

