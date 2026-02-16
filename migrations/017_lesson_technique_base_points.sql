-- Pontuação base por lição e por técnica (gamificação: base × multiplicador da faixa do oponente).
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS base_points INTEGER NULL DEFAULT 10;
ALTER TABLE techniques ADD COLUMN IF NOT EXISTS base_points INTEGER NULL DEFAULT 10;
COMMENT ON COLUMN lessons.base_points IS 'Pontos base da lição; pontos finais = base_points × faixa do oponente (1-5).';
COMMENT ON COLUMN techniques.base_points IS 'Pontos base da técnica; usado quando execução é por missão (fallback se lição não tiver base_points).';
