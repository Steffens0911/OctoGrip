-- Contador de cliques no botão "Chamar no WhatsApp" por anúncio
ALTER TABLE academy_marketplace_items
    ADD COLUMN IF NOT EXISTS whatsapp_clicks INTEGER NOT NULL DEFAULT 0;
