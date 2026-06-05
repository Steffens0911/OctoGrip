-- Foto privada 3x4 para reconhecimento facial, separada do avatar de perfil.
ALTER TABLE users ADD COLUMN IF NOT EXISTS facial_photo_url TEXT;
