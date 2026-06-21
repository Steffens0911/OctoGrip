-- Fase 3: vínculo entre sessão de chamada e treino lançado (pré-checkin)

ALTER TABLE attendance_sessions
    ADD COLUMN IF NOT EXISTS training_session_id UUID
        REFERENCES training_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_attendance_sessions_training_session
    ON attendance_sessions(training_session_id)
    WHERE training_session_id IS NOT NULL;
