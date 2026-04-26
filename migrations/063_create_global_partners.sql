CREATE TABLE IF NOT EXISTS global_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    logo_url VARCHAR(512),
    offer_text TEXT,
    external_url VARCHAR(512),
    featured_order INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_global_partners_active_order
    ON global_partners (featured_order)
    WHERE is_active = true;
