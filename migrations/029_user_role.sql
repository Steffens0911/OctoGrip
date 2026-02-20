-- Migration 029: Adicionar campo role na tabela users
-- Role: aluno, professor, gerente_academia, administrador, supervisor
-- Valores padrão: 'aluno' para registros existentes

-- Adicionar coluna role se não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'role'
    ) THEN
        ALTER TABLE users ADD COLUMN role VARCHAR(32) NOT NULL DEFAULT 'aluno';
        CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
        COMMENT ON COLUMN users.role IS 'Role: aluno, professor, gerente_academia, administrador, supervisor';
    END IF;
END $$;
