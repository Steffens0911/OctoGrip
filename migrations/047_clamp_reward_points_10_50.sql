-- Padroniza pontuação de vídeo diário e missões (10–50).
-- Executar após deploy do código que valida o mesmo intervalo.

UPDATE training_videos SET points_per_day = 10 WHERE points_per_day < 10;
UPDATE training_videos SET points_per_day = 50 WHERE points_per_day > 50;

UPDATE missions SET multiplier = 10 WHERE multiplier < 10;
UPDATE missions SET multiplier = 50 WHERE multiplier > 50;

UPDATE academies SET weekly_multiplier_1 = 10 WHERE weekly_multiplier_1 < 10;
UPDATE academies SET weekly_multiplier_1 = 50 WHERE weekly_multiplier_1 > 50;
UPDATE academies SET weekly_multiplier_2 = 10 WHERE weekly_multiplier_2 < 10;
UPDATE academies SET weekly_multiplier_2 = 50 WHERE weekly_multiplier_2 > 50;
UPDATE academies SET weekly_multiplier_3 = 10 WHERE weekly_multiplier_3 < 10;
UPDATE academies SET weekly_multiplier_3 = 50 WHERE weekly_multiplier_3 > 50;

ALTER TABLE academies ALTER COLUMN weekly_multiplier_1 SET DEFAULT 10;
ALTER TABLE academies ALTER COLUMN weekly_multiplier_2 SET DEFAULT 10;
ALTER TABLE academies ALTER COLUMN weekly_multiplier_3 SET DEFAULT 10;
ALTER TABLE missions ALTER COLUMN multiplier SET DEFAULT 10;
ALTER TABLE training_videos ALTER COLUMN points_per_day SET DEFAULT 10;
