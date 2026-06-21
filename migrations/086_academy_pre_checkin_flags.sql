-- Fase 0: flags de pré-checkin por academia (gate por assinatura)
-- pre_checkin_enabled: só admin global edita; liga o sistema de treino + pré-checkin
-- pre_checkin_strict: professor edita; sem pré-checkin = sem presença automática

ALTER TABLE academies
    ADD COLUMN IF NOT EXISTS pre_checkin_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS pre_checkin_strict  BOOLEAN NOT NULL DEFAULT FALSE;
