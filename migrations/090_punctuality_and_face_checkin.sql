-- Fase 6: pontualidade + quiosque facial de chegada.

-- Registro se o aluno foi pontual nessa sessão (NULL = sem treino vinculado)
ALTER TABLE attendance_records
  ADD COLUMN IF NOT EXISTS was_punctual BOOLEAN DEFAULT NULL;

-- Streak de pontualidade por treino (independente do streak de login diário)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS punctuality_streak      INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS punctuality_streak_best INTEGER NOT NULL DEFAULT 0;

-- XP por pontualidade (configurável por academia) + flag do quiosque facial
ALTER TABLE academies
  ADD COLUMN IF NOT EXISTS punctuality_xp        INTEGER NOT NULL DEFAULT 15,
  ADD COLUMN IF NOT EXISTS face_checkin_enabled  BOOLEAN NOT NULL DEFAULT FALSE;
