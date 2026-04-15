-- Anúncios de produtos por academia (marketplace no campo de treinamento).

CREATE TABLE IF NOT EXISTS academy_marketplace_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    academy_id UUID NOT NULL REFERENCES academies(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price_cents INTEGER NOT NULL DEFAULT 0,
    currency VARCHAR(8) NOT NULL DEFAULT 'BRL',
    image_url VARCHAR(512),
    whatsapp_url VARCHAR(1024) NOT NULL,
    sort_order INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_id UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_academy_marketplace_items_academy_active_sort
    ON academy_marketplace_items (academy_id, is_active, sort_order NULLS LAST);

CREATE INDEX IF NOT EXISTS ix_academy_marketplace_items_created_by_id
    ON academy_marketplace_items (created_by_id);

COMMENT ON TABLE academy_marketplace_items IS 'Anúncios de produtos da academia (preço, foto, link WhatsApp); venda fora do app.';
COMMENT ON COLUMN academy_marketplace_items.price_cents IS 'Preço em centavos (ex.: 19990 = R$ 199,90).';
COMMENT ON COLUMN academy_marketplace_items.whatsapp_url IS 'URL completa wa.me com texto opcional.';
