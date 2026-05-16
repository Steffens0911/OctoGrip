-- Preserva execuções quando o oponente é deletado (SET NULL em vez de CASCADE).
-- Antes: opponent_id NOT NULL REFERENCES users ON DELETE CASCADE
-- Depois: opponent_id NULL      REFERENCES users ON DELETE SET NULL

ALTER TABLE technique_executions
    ALTER COLUMN opponent_id DROP NOT NULL;

ALTER TABLE technique_executions
    DROP CONSTRAINT IF EXISTS technique_executions_opponent_id_fkey;

ALTER TABLE technique_executions
    ADD CONSTRAINT technique_executions_opponent_id_fkey
    FOREIGN KEY (opponent_id) REFERENCES users(id) ON DELETE SET NULL;
