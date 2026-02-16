-- Graduação (faixa) do usuário para pontuação gamificada.
ALTER TABLE users ADD COLUMN IF NOT EXISTS graduation VARCHAR(32) NULL;
COMMENT ON COLUMN users.graduation IS 'Faixa: white, blue, purple, brown, black (pontos 1-5).';
