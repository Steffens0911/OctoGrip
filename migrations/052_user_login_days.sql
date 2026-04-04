-- Um registro por dia (UTC) em que o usuário fez login com sucesso (sequência / streak).
CREATE TABLE IF NOT EXISTS user_login_days (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  login_day DATE NOT NULL,
  PRIMARY KEY (user_id, login_day)
);

CREATE INDEX IF NOT EXISTS idx_user_login_days_user_day
  ON user_login_days (user_id, login_day DESC);

COMMENT ON TABLE user_login_days IS 'Dias UTC com pelo menos um login bem-sucedido; usado para login_streak_days em /auth/me.';

-- Backfill: um dia a partir do último login conhecido (não reconstrói histórico completo).
INSERT INTO user_login_days (user_id, login_day)
SELECT id, (last_login_at AT TIME ZONE 'UTC')::date
FROM users
WHERE last_login_at IS NOT NULL
ON CONFLICT DO NOTHING;
