-- Soft-delete por usuário: cada aluno pode excluir sua própria notificação
-- sem afetar as notificações dos outros usuários.
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS ix_notifications_deleted
    ON notifications (user_id, deleted);
