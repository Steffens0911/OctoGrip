-- Execuções de técnica com adversário e confirmação (gamificação).
CREATE TABLE IF NOT EXISTS technique_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mission_id UUID NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    opponent_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    usage_type VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending_confirmation',
    outcome VARCHAR(32) NULL,
    points_awarded INTEGER NULL,
    confirmed_at TIMESTAMPTZ NULL,
    confirmed_by UUID NULL REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS ix_technique_executions_user_id ON technique_executions(user_id);
CREATE INDEX IF NOT EXISTS ix_technique_executions_mission_id ON technique_executions(mission_id);
CREATE INDEX IF NOT EXISTS ix_technique_executions_opponent_id ON technique_executions(opponent_id);
CREATE INDEX IF NOT EXISTS ix_technique_executions_status ON technique_executions(status);
COMMENT ON TABLE technique_executions IS 'Execução de técnica em adversário; pontos só após confirmação.';
COMMENT ON COLUMN technique_executions.usage_type IS 'before_training | after_training';
COMMENT ON COLUMN technique_executions.status IS 'pending_confirmation | confirmed | rejected';
COMMENT ON COLUMN technique_executions.outcome IS 'attempted_correctly | executed_successfully (preenchido na confirmação)';
