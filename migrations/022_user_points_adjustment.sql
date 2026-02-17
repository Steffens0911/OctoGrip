-- Ajuste manual de pontos por admin da academia (soma ao total computado)
ALTER TABLE users ADD COLUMN IF NOT EXISTS points_adjustment INTEGER NOT NULL DEFAULT 0;
