-- Missões por academia identificadas por slot_index (0, 1, 2) em vez de datas.
-- start_date/end_date passam a ser opcionais (legado).

ALTER TABLE missions ADD COLUMN IF NOT EXISTS slot_index INTEGER NULL;
COMMENT ON COLUMN missions.slot_index IS 'Slot da academia (0, 1, 2). NULL para missões globais/legado.';

-- Preencher slot_index a partir de start_date para missões de academia (datas fixas antigas).
UPDATE missions SET slot_index = 0
WHERE academy_id IS NOT NULL AND start_date = '2020-01-06' AND slot_index IS NULL;
UPDATE missions SET slot_index = 1
WHERE academy_id IS NOT NULL AND start_date = '2020-01-08' AND slot_index IS NULL;
UPDATE missions SET slot_index = 2
WHERE academy_id IS NOT NULL AND start_date = '2020-01-10' AND slot_index IS NULL;

-- Permitir datas nulas (missões novas só usam slot_index).
ALTER TABLE missions ALTER COLUMN start_date DROP NOT NULL;
ALTER TABLE missions ALTER COLUMN end_date DROP NOT NULL;

CREATE INDEX IF NOT EXISTS ix_missions_academy_level_slot
ON missions(academy_id, level, slot_index)
WHERE academy_id IS NOT NULL AND slot_index IS NOT NULL;
