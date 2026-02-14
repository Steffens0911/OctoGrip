-- Link do YouTube para técnica (opcional).
ALTER TABLE techniques ADD COLUMN IF NOT EXISTS video_url VARCHAR(512) NULL;
COMMENT ON COLUMN techniques.video_url IS 'URL do vídeo (ex.: link do YouTube).';
