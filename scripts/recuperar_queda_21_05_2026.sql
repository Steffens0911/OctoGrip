-- ============================================================
-- Recuperação pós-queda do servidor: 21/05/2026
-- Objetivo: registrar login e visualização de vídeo para todos
-- os usuários como se tivessem feito ontem, evitando perda de
-- sequência.  ON CONFLICT DO NOTHING protege quem já fez tudo.
-- Fuso da aplicação: America/Sao_Paulo (UTC-3).
-- ============================================================

BEGIN;

-- ----------------------------------------------------------
-- 1. Dia de login de ontem para TODOS os usuários
--    (PK composta user_id+login_day garante idempotência)
-- ----------------------------------------------------------
INSERT INTO user_login_days (user_id, login_day)
SELECT id, '2026-05-21'::date
FROM users
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------
-- 2. Atualiza last_login_at para quem não tinha registro recente
--    (apenas visual/informativo; a streak usa user_login_days)
-- ----------------------------------------------------------
UPDATE users
SET last_login_at = '2026-05-21 23:59:00-03'::timestamptz
WHERE last_login_at IS NULL
   OR last_login_at < '2026-05-21 00:00:00-03'::timestamptz;

-- ----------------------------------------------------------
-- 3. Visualização dos vídeos ativos de ontem
--    Regras de visibilidade (igual ao app):
--      - vídeo global (academy_id IS NULL): todos os usuários
--      - vídeo local: apenas usuários da mesma academia
--    ON CONFLICT respeita quem já assistiu de verdade.
-- ----------------------------------------------------------
INSERT INTO training_video_daily_views
    (id, user_id, training_video_id, view_date, completed_at, points_awarded)
SELECT
    gen_random_uuid(),
    u.id,
    v.id,
    '2026-05-21'::date,
    '2026-05-21 23:59:00-03'::timestamptz,
    v.points_per_day
FROM users u
JOIN training_videos v ON (
    v.is_active = true
    AND (
        v.academy_id IS NULL            -- vídeo global: visível por todos
        OR v.academy_id = u.academy_id  -- vídeo local: apenas a academia do usuário
    )
)
ON CONFLICT ON CONSTRAINT uq_training_video_daily_view_unique DO NOTHING;

-- ----------------------------------------------------------
-- 4. Relatório: quantos registros foram inseridos/atualizados
-- ----------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM user_login_days      WHERE login_day  = '2026-05-21')         AS logins_ontem,
    (SELECT COUNT(*) FROM training_video_daily_views WHERE view_date = '2026-05-21')     AS views_ontem,
    (SELECT COUNT(*) FROM users WHERE last_login_at >= '2026-05-21 00:00:00-03'::timestamptz) AS usuarios_com_login_ontem;

COMMIT;
