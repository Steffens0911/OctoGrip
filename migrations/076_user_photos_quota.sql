-- Quota de fotos por aluno por academia.
-- Permite ao professor configurar quantas fotos cada aluno pode ter no feed.
-- Moderadores (professor/gerente) são isentos do limite.

BEGIN;

ALTER TABLE academies
    ADD COLUMN IF NOT EXISTS user_photos_quota INTEGER NOT NULL DEFAULT 30
    CONSTRAINT chk_user_photos_quota CHECK (user_photos_quota >= 1);

COMMENT ON COLUMN academies.user_photos_quota IS
    'Número máximo de fotos que cada aluno pode ter publicadas nesta academia. Moderadores são isentos.';

COMMIT;
