-- Posições e técnicas por academia (portfólio próprio)
-- Blocos DO usam $$ para o parser em run_migrations.py. Operações em positions só se a tabela existir (ex.: após 045).

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'positions'
  ) THEN
    ALTER TABLE positions ADD COLUMN IF NOT EXISTS academy_id UUID REFERENCES academies(id) ON DELETE CASCADE;
  END IF;
END $$;

ALTER TABLE techniques ADD COLUMN IF NOT EXISTS academy_id UUID REFERENCES academies(id) ON DELETE CASCADE;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS academy_id UUID REFERENCES academies(id) ON DELETE SET NULL;

-- 1b. Garantir colunas de flags na academies (com DEFAULT) para INSERT abaixo funcionar quando a tabela veio de create_all
ALTER TABLE academies ADD COLUMN IF NOT EXISTS show_trophies BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE academies ADD COLUMN IF NOT EXISTS show_partners BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE academies ADD COLUMN IF NOT EXISTS show_schedule BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE academies ADD COLUMN IF NOT EXISTS show_global_supporters BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE academies ALTER COLUMN show_trophies SET DEFAULT true;
ALTER TABLE academies ALTER COLUMN show_partners SET DEFAULT true;
ALTER TABLE academies ALTER COLUMN show_schedule SET DEFAULT true;
ALTER TABLE academies ALTER COLUMN show_global_supporters SET DEFAULT true;

-- 2. Criar academia Red Lions se não existir
INSERT INTO academies (id, name, slug, weekly_multiplier_1, weekly_multiplier_2, weekly_multiplier_3)
SELECT gen_random_uuid(), 'Red Lions', 'red-lions', 1, 1, 1
WHERE NOT EXISTS (SELECT 1 FROM academies WHERE LOWER(name) = 'red lions');

-- 3. Vincular dados existentes à Red Lions
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'positions'
  ) THEN
    UPDATE positions SET academy_id = (SELECT id FROM academies WHERE LOWER(name) = 'red lions' LIMIT 1)
    WHERE academy_id IS NULL;
  END IF;
END $$;

UPDATE techniques SET academy_id = (SELECT id FROM academies WHERE LOWER(name) = 'red lions' LIMIT 1)
WHERE academy_id IS NULL;

UPDATE lessons SET academy_id = (SELECT t.academy_id FROM techniques t WHERE t.id = lessons.technique_id)
WHERE academy_id IS NULL AND technique_id IS NOT NULL;

-- 4. Tornar academy_id obrigatório (positions só se existir)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'positions'
  ) THEN
    ALTER TABLE positions ALTER COLUMN academy_id SET NOT NULL;
  END IF;
END $$;

ALTER TABLE techniques ALTER COLUMN academy_id SET NOT NULL;

-- 5. Slug único por academia (positions só se existir)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'positions'
  ) THEN
    ALTER TABLE positions DROP CONSTRAINT IF EXISTS positions_slug_key;
    CREATE UNIQUE INDEX IF NOT EXISTS positions_academy_slug_key ON positions (academy_id, slug);
  END IF;
END $$;

ALTER TABLE techniques DROP CONSTRAINT IF EXISTS techniques_slug_key;
CREATE UNIQUE INDEX IF NOT EXISTS techniques_academy_slug_key ON techniques (academy_id, slug);
