-- Marketplace: telefone BR opcional (55+DDD+número); URL wa.me gerada na API com texto fixo.
-- Idempotente: o backfill só corre se ainda existir a coluna legada whatsapp_url.

ALTER TABLE academy_marketplace_items
    ADD COLUMN IF NOT EXISTS whatsapp_phone VARCHAR(20);

COMMENT ON COLUMN academy_marketplace_items.whatsapp_phone IS 'Apenas dígitos E164 BR (ex.: 5511999999999); NULL = sem WhatsApp no anúncio.';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'academy_marketplace_items'
      AND column_name = 'whatsapp_url'
  ) THEN
    UPDATE academy_marketplace_items
    SET whatsapp_phone = NULLIF(
        regexp_replace(
            split_part(split_part(lower(whatsapp_url), 'wa.me/', 2), '?', 1),
            '[^0-9]',
            '',
            'g'
        ),
        ''
    )
    WHERE whatsapp_url IS NOT NULL
      AND lower(whatsapp_url) LIKE '%wa.me/%'
      AND (whatsapp_phone IS NULL OR whatsapp_phone = '');
  END IF;
END $$;

ALTER TABLE academy_marketplace_items DROP COLUMN IF EXISTS whatsapp_url;
