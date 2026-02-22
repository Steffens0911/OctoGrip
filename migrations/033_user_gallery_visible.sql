-- Preferência do usuário: galeria de troféus visível ou privada para outros usuários.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS gallery_visible BOOLEAN NOT NULL DEFAULT true;
COMMENT ON COLUMN users.gallery_visible IS 'Se true, outros usuários podem ver a galeria de troféus (apenas itens conquistados). Se false, a galeria fica privada.';
