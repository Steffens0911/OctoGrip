-- Multiplicador por missão: pontos ao concluir = multiplier × faixa (1-5).
ALTER TABLE missions ADD COLUMN IF NOT EXISTS multiplier INTEGER NOT NULL DEFAULT 1;
COMMENT ON COLUMN missions.multiplier IS 'Multiplicador: pontos = multiplier × valor da faixa (1-5) ao concluir missão.';

-- Multiplicadores por slot semanal da academia (seg-ter, qua-qui, sex-dom).
ALTER TABLE academies ADD COLUMN IF NOT EXISTS weekly_multiplier_1 INTEGER NOT NULL DEFAULT 1;
ALTER TABLE academies ADD COLUMN IF NOT EXISTS weekly_multiplier_2 INTEGER NOT NULL DEFAULT 1;
ALTER TABLE academies ADD COLUMN IF NOT EXISTS weekly_multiplier_3 INTEGER NOT NULL DEFAULT 1;
COMMENT ON COLUMN academies.weekly_multiplier_1 IS 'Multiplicador slot 1 (seg-ter).';
COMMENT ON COLUMN academies.weekly_multiplier_2 IS 'Multiplicador slot 2 (qua-qui).';
COMMENT ON COLUMN academies.weekly_multiplier_3 IS 'Multiplicador slot 3 (sex-dom).';

-- Pontos concedidos ao concluir missão (mission_complete).
ALTER TABLE mission_usages ADD COLUMN IF NOT EXISTS points_awarded INTEGER NULL;
COMMENT ON COLUMN mission_usages.points_awarded IS 'Pontos ao concluir a missão (= mission.multiplier, faixa 10–50).';
