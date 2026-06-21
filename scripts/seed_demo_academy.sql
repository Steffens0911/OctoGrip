-- =====================================================================
-- Seed de ACADEMIA DE DEMONSTRAÇÃO / TESTES (Octogrip)
-- ---------------------------------------------------------------------
-- Cria uma academia completa e isolada sob o slug 'demo-octogrip' e
-- e-mails @demo.octogrip.com.br: alunos (faixas/níveis/streaks variados),
-- professores, gerente, técnicas/posições, slots e kits semanais, missões,
-- troféus automáticos (com conquistas), medalhas manuais e de campeonato,
-- execuções confirmadas, conclusões de missão, presença, metas coletivas,
-- parceiros, vídeos, marketplace e notificações.
--
-- IDEMPOTENTE: se a academia demo já existir, ela é APAGADA e recriada.
-- Seguro: mexe apenas no que pertence à academia demo.
--
-- Como rodar (psql conectado ao banco de produção):
--     \i /caminho/seed_demo_academy.sql
--   ou
--     psql -U jjb -d jjb_db -f scripts/seed_demo_academy.sql
--
-- Senha de TODOS os usuários demo: Demo@1234
-- =====================================================================

DO $$
DECLARE
    -- Constantes
    v_pwd        text := '$pbkdf2-sha256$29000$h5AyZowxppQy5nzPGWMMoQ$eGMWGCMmfnQM5epkgKsAF3rwTWm/aGM4RYuD./6X7Vg';
    v_today      date := CURRENT_DATE;
    v_now        timestamptz := now();
    v_week_start date;

    -- IDs principais
    v_academy uuid;
    v_manager uuid;
    v_prof    uuid;
    v_prof2   uuid;
    v_kit1    uuid;
    v_kit2    uuid;
    v_champ   uuid;
    v_tpl_destaque uuid;
    v_tpl_disc     uuid;
    v_tpl_medal    uuid;
    v_sess    uuid;
    v_id      uuid;

    -- Coleções
    v_tech     uuid[] := '{}';
    v_lesson   uuid[] := '{}';
    v_lm_id    uuid[] := '{}';   -- missões legado (id)
    v_lm_mult  int[]  := '{}';   -- missões legado (multiplier)
    v_trophy   uuid[] := '{}';
    v_students uuid[] := '{}';
    v_totals   int[]  := '{}';

    -- Dados estáticos
    v_tech_names text[] := ARRAY[
        'Mata-Leão','Armlock da Guarda Fechada','Triângulo','Kimura','Omoplata','Americana',
        'Raspagem de Tesoura','Raspagem de Gancho','Passagem de Guarda em Pé','Escape da Montada',
        'Pegada nas Costas','Berimbolo'];
    v_tech_slugs text[] := ARRAY[
        'mata-leao','armlock-da-guarda-fechada','triangulo','kimura','omoplata','americana',
        'raspagem-de-tesoura','raspagem-de-gancho','passagem-de-guarda-em-pe','escape-da-montada',
        'pegada-nas-costas','berimbolo'];
    v_tech_pts int[] := ARRAY[10,10,15,10,15,10,10,10,15,10,15,20];

    v_names text[] := ARRAY[
        'Lucas Almeida','Mariana Costa','Rafael Souza','Beatriz Lima','Gabriel Rocha',
        'Juliana Martins','Felipe Carvalho','Camila Ferreira','Bruno Oliveira','Larissa Gomes',
        'Thiago Ribeiro','Amanda Barbosa','Diego Nunes','Patrícia Araújo','Vinícius Pinto',
        'Fernanda Dias','Rodrigo Teixeira','Aline Cardoso','Marcelo Castro','Carolina Moraes',
        'Eduardo Ramos','Tatiane Freitas','Gustavo Mendes','Priscila Lopes','André Correia'];
    v_belts text[] := ARRAY[
        'white','white','white','white','white','white','white','white','white','white',
        'blue','blue','blue','blue','blue','blue','blue',
        'purple','purple','purple','purple',
        'brown','brown','brown',
        'black'];

    v_trophy_names    text[] := ARRAY['Caçador de Costas','Mestre do Triângulo','Rei da Raspagem','Finalizador'];
    v_trophy_techidx  int[]  := ARRAY[11,3,7,1];   -- índices (1-based) em v_tech
    v_trophy_target   int[]  := ARRAY[15,10,12,20];
    v_tiers           text[] := ARRAY['gold','silver','bronze'];

    -- Auxiliares de loop
    i int; k int; s int; lv int; d int; x int;
    midx int; oidx int; t1 int; t2 int; cnt int; npres int; dday int;
    intensity int; total int; pts int; n_missions int; n_exec int;
    lvl int; rem int; thr int; streak_len int; end_offset int; mult int;
    level_name text; frozen boolean;
    completed timestamptz; confirmed timestamptz;
    r record;
BEGIN
    PERFORM setseed(0.4242);
    v_week_start := v_today - (extract(isodow from v_today)::int - 1);

    -- =================================================================
    -- 0) RESET: apaga academia demo existente (ordem segura de FKs)
    -- =================================================================
    SELECT id INTO v_academy FROM academies WHERE slug = 'demo-octogrip';
    IF v_academy IS NOT NULL THEN
        RAISE NOTICE 'Academia demo já existe (%). Apagando para recriar...', v_academy;

        DELETE FROM user_trophy_earned WHERE user_id IN (SELECT id FROM users WHERE academy_id = v_academy);
        IF to_regclass('public.academy_trophy_awards') IS NOT NULL THEN
            DELETE FROM academy_trophy_awards WHERE user_id IN (SELECT id FROM users WHERE academy_id = v_academy);
        END IF;
        DELETE FROM technique_executions WHERE user_id IN (SELECT id FROM users WHERE academy_id = v_academy);
        DELETE FROM mission_usages WHERE user_id IN (SELECT id FROM users WHERE academy_id = v_academy);
        DELETE FROM notifications WHERE user_id IN (SELECT id FROM users WHERE academy_id = v_academy);
        DELETE FROM user_login_days WHERE user_id IN (SELECT id FROM users WHERE academy_id = v_academy);
        DELETE FROM attendance_records WHERE session_id IN (SELECT id FROM attendance_sessions WHERE academy_id = v_academy);
        DELETE FROM attendance_sessions WHERE academy_id = v_academy;
        IF to_regclass('public.academy_championship_events') IS NOT NULL THEN
            DELETE FROM academy_championship_events WHERE academy_id = v_academy;
        END IF;
        IF to_regclass('public.academy_trophy_templates') IS NOT NULL THEN
            DELETE FROM academy_trophy_templates WHERE academy_id = v_academy;
        END IF;
        DELETE FROM missions WHERE academy_id = v_academy;
        DELETE FROM weekly_kit_items WHERE kit_id IN (SELECT id FROM weekly_technique_kits WHERE academy_id = v_academy);
        IF to_regclass('public.user_weekly_kit_choices') IS NOT NULL THEN
            DELETE FROM user_weekly_kit_choices WHERE academy_id = v_academy;
        END IF;
        DELETE FROM weekly_technique_kits WHERE academy_id = v_academy;
        DELETE FROM collective_goals WHERE academy_id = v_academy;
        DELETE FROM trophies WHERE academy_id = v_academy;
        DELETE FROM lessons WHERE academy_id = v_academy;
        DELETE FROM training_videos WHERE academy_id = v_academy;
        IF to_regclass('public.academy_marketplace_items') IS NOT NULL THEN
            DELETE FROM academy_marketplace_items WHERE academy_id = v_academy;
        END IF;
        DELETE FROM partners WHERE academy_id = v_academy;
        UPDATE academies SET weekly_technique_id = NULL, weekly_technique_2_id = NULL,
               weekly_technique_3_id = NULL, visible_lesson_id = NULL WHERE id = v_academy;
        DELETE FROM techniques WHERE academy_id = v_academy;
        DELETE FROM users WHERE academy_id = v_academy;
        DELETE FROM professors WHERE academy_id = v_academy;
        DELETE FROM academies WHERE id = v_academy;
        v_academy := NULL;
    END IF;

    -- =================================================================
    -- 1) Academia
    -- =================================================================
    v_academy := gen_random_uuid();
    INSERT INTO academies (id, name, slug, logo_url, schedule_image_url,
        weekly_multiplier_1, weekly_multiplier_2, weekly_multiplier_3,
        login_notice_title, login_notice_body, login_notice_active,
        face_recognition_enabled, qr_attendance_enabled)
    VALUES (v_academy, 'Academia Octogrip — Demonstração', 'demo-octogrip',
        'https://placehold.co/200x200/png?text=Octogrip',
        'https://placehold.co/800x1000/png?text=Quadro+de+Horarios',
        10, 15, 20,
        'Bem-vindo ao Octogrip!',
        'Esta é a academia de demonstração. Explore missões, troféus e o ranking semanal.',
        true, true, true);

    -- =================================================================
    -- 2) Técnicas / posições
    -- =================================================================
    FOR i IN 1..array_length(v_tech_names, 1) LOOP
        v_id := gen_random_uuid();
        INSERT INTO techniques (id, academy_id, name, slug, description, video_url, base_points)
        VALUES (v_id, v_academy, v_tech_names[i], v_tech_slugs[i],
            'Técnica de demonstração: ' || v_tech_names[i] || '.',
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ', v_tech_pts[i]);
        v_tech := array_append(v_tech, v_id);
    END LOOP;

    -- =================================================================
    -- 3) Lições (4 primeiras técnicas)
    -- =================================================================
    FOR i IN 1..4 LOOP
        v_id := gen_random_uuid();
        INSERT INTO lessons (id, academy_id, title, slug, video_url, content, order_index, base_points, technique_id)
        VALUES (v_id, v_academy, 'Como aplicar: ' || v_tech_names[i], 'licao-' || v_tech_slugs[i],
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            'Passo a passo da técnica ' || v_tech_names[i] || '.', i - 1, 10, v_tech[i]);
        v_lesson := array_append(v_lesson, v_id);
    END LOOP;

    UPDATE academies SET weekly_technique_id = v_tech[1], weekly_technique_2_id = v_tech[2],
           weekly_technique_3_id = v_tech[3], visible_lesson_id = v_lesson[1]
    WHERE id = v_academy;

    -- =================================================================
    -- 4) Kits semanais (turmas) + itens
    -- =================================================================
    v_kit1 := gen_random_uuid();
    INSERT INTO weekly_technique_kits (id, academy_id, label, sort_order)
    VALUES (v_kit1, v_academy, 'Turma Iniciante', 0);
    FOR i IN 1..3 LOOP
        INSERT INTO weekly_kit_items (id, kit_id, order_index, technique_id, multiplier)
        VALUES (gen_random_uuid(), v_kit1, i - 1, v_tech[i], 10 + (i - 1) * 5);
    END LOOP;

    v_kit2 := gen_random_uuid();
    INSERT INTO weekly_technique_kits (id, academy_id, label, sort_order)
    VALUES (v_kit2, v_academy, 'Turma Avançada', 1);
    FOR i IN 1..3 LOOP
        INSERT INTO weekly_kit_items (id, kit_id, order_index, technique_id, multiplier)
        VALUES (gen_random_uuid(), v_kit2, i - 1, v_tech[i + 3], 10 + (i - 1) * 5);
    END LOOP;

    -- =================================================================
    -- 5) Missões (slots legado por nível + missões de kit)
    -- =================================================================
    FOR s IN 0..2 LOOP
        mult := CASE s WHEN 0 THEN 10 WHEN 1 THEN 15 ELSE 20 END;
        FOR lv IN 0..s LOOP
            level_name := (ARRAY['beginner','intermediate','advanced'])[lv + 1];
            v_id := gen_random_uuid();
            INSERT INTO missions (id, technique_id, slot_index, start_date, end_date, is_active, level, theme, academy_id, multiplier)
            VALUES (v_id, v_tech[s + 1], s, v_today - 2, v_today + 5, true, level_name, 'Semana de finalizações', v_academy, mult);
            v_lm_id   := array_append(v_lm_id, v_id);
            v_lm_mult := array_append(v_lm_mult, mult);
        END LOOP;
    END LOOP;
    -- Missões de kit (não entram no pool de pontuação legado)
    FOR i IN 1..3 LOOP
        INSERT INTO missions (id, technique_id, slot_index, start_date, end_date, is_active, level, academy_id, weekly_kit_id, multiplier)
        VALUES (gen_random_uuid(), v_tech[i], i - 1, v_today - 2, v_today + 5, true, 'beginner', v_academy, v_kit1, 10 + (i - 1) * 5);
        INSERT INTO missions (id, technique_id, slot_index, start_date, end_date, is_active, level, academy_id, weekly_kit_id, multiplier)
        VALUES (gen_random_uuid(), v_tech[i + 3], i - 1, v_today - 2, v_today + 5, true, 'beginner', v_academy, v_kit2, 10 + (i - 1) * 5);
    END LOOP;

    -- =================================================================
    -- 6) Staff: gerente + 2 professores
    -- =================================================================
    v_manager := gen_random_uuid();
    INSERT INTO users (id, email, password_hash, name, points_adjustment, graduation, role, academy_id, gallery_visible, last_login_at)
    VALUES (v_manager, 'gerente@demo.octogrip.com.br', v_pwd, 'Sérgio Gestor', 0, 'black', 'gerente_academia', v_academy, true, v_now - interval '3 hours');

    v_prof := gen_random_uuid();
    INSERT INTO users (id, email, password_hash, name, points_adjustment, graduation, role, academy_id, gallery_visible, last_login_at)
    VALUES (v_prof, 'professor@demo.octogrip.com.br', v_pwd, 'Professor Faixa-Preta', 0, 'black', 'professor', v_academy, true, v_now - interval '5 hours');

    v_prof2 := gen_random_uuid();
    INSERT INTO users (id, email, password_hash, name, points_adjustment, graduation, role, academy_id, gallery_visible, last_login_at)
    VALUES (v_prof2, 'professora@demo.octogrip.com.br', v_pwd, 'Professora Coral', 0, 'black', 'professor', v_academy, true, v_now - interval '8 hours');

    INSERT INTO professors (id, name, email, academy_id) VALUES
        (gen_random_uuid(), 'Professor Faixa-Preta', 'professor@demo.octogrip.com.br', v_academy),
        (gen_random_uuid(), 'Professora Coral', 'professora@demo.octogrip.com.br', v_academy);

    -- =================================================================
    -- 7) Alunos
    -- =================================================================
    FOR i IN 1..25 LOOP
        v_id := gen_random_uuid();
        frozen := (i IN (8, 19));
        INSERT INTO users (id, email, password_hash, name, points_adjustment, graduation, role, academy_id,
            gallery_visible, account_frozen, account_freeze_reason, avatar_url, last_login_at)
        VALUES (v_id, 'aluno' || lpad(i::text, 2, '0') || '@demo.octogrip.com.br', v_pwd, v_names[i], 0,
            v_belts[i], 'aluno', v_academy, true, frozen,
            CASE WHEN frozen THEN 'Mensalidade em aberto' ELSE NULL END,
            'https://i.pravatar.cc/150?u=aluno' || i,
            v_now - make_interval(days => floor(random() * 7)::int, hours => floor(random() * 24)::int));
        v_students := array_append(v_students, v_id);
    END LOOP;

    -- =================================================================
    -- 8) Streak: dias de login (varia por aluno)
    -- =================================================================
    FOR i IN 1..25 LOOP
        streak_len := (ARRAY[0,1,2,3,5,7,10,14])[((i - 1) % 8) + 1];
        end_offset := CASE WHEN ((i - 1) % 3) = 0 THEN 1 ELSE 0 END;
        FOR d IN 0..(streak_len - 1) LOOP
            INSERT INTO user_login_days (user_id, login_day) VALUES (v_students[i], v_today - end_offset - d);
        END LOOP;
    END LOOP;

    -- =================================================================
    -- 9) Atividade da semana: conclusões de missão + execuções confirmadas
    --    (alimenta pontos, nível e ranking semanal)
    -- =================================================================
    FOR i IN 1..25 LOOP
        intensity := 25 - (i - 1);
        total := 0;

        n_missions := least(6, 1 + intensity / 4);
        FOR k IN 1..n_missions LOOP
            midx := 1 + floor(random() * array_length(v_lm_id, 1))::int;
            pts := v_lm_mult[midx];
            completed := v_now - make_interval(days => floor(random() * 7)::int, hours => floor(random() * 24)::int);
            INSERT INTO mission_usages (id, user_id, mission_id, opened_at, completed_at, usage_type, points_awarded)
            VALUES (gen_random_uuid(), v_students[i], v_lm_id[midx], completed - interval '20 minutes', completed, 'after_training', pts);
            total := total + pts;
        END LOOP;

        n_exec := least(8, intensity / 3);
        FOR k IN 1..n_exec LOOP
            oidx := 1 + floor(random() * 25)::int;
            WHILE oidx = i LOOP oidx := 1 + floor(random() * 25)::int; END LOOP;
            midx := 1 + floor(random() * array_length(v_lm_id, 1))::int;
            pts := (ARRAY[10,15,20])[1 + floor(random() * 3)::int];
            confirmed := v_now - make_interval(days => floor(random() * 7)::int, hours => floor(random() * 24)::int);
            -- Atenção ao CHECK chk_execution_source: apenas mission_id preenchido.
            INSERT INTO technique_executions (id, user_id, mission_id, opponent_id, usage_type, status, outcome, points_awarded, confirmed_at, confirmed_by)
            VALUES (gen_random_uuid(), v_students[i], v_lm_id[midx], v_students[oidx], 'after_training', 'confirmed', 'success', pts, confirmed, v_prof);
            total := total + pts;
        END LOOP;

        -- ~40% têm uma execução pendente de confirmação (não pontua ainda)
        IF random() < 0.4 THEN
            oidx := 1 + floor(random() * 25)::int;
            WHILE oidx = i LOOP oidx := 1 + floor(random() * 25)::int; END LOOP;
            midx := 1 + floor(random() * array_length(v_lm_id, 1))::int;
            INSERT INTO technique_executions (id, user_id, mission_id, opponent_id, usage_type, status)
            VALUES (gen_random_uuid(), v_students[i], v_lm_id[midx], v_students[oidx], 'after_training', 'pending_confirmation');
        END IF;

        v_totals[i] := total;
    END LOOP;

    -- =================================================================
    -- 10) Níveis (reward_level) coerentes com os pontos gerados
    --     Replica app/core/leveling.py: base 50, crescimento *1.2 (inteiro).
    -- =================================================================
    FOR i IN 1..25 LOOP
        lvl := 1; rem := v_totals[i];
        LOOP
            thr := 50;
            FOR x IN 2..lvl LOOP thr := (thr * 6 + 4) / 5; END LOOP;
            IF rem >= thr THEN rem := rem - thr; lvl := lvl + 1; ELSE EXIT; END IF;
        END LOOP;
        UPDATE users SET reward_level = lvl, reward_level_points = rem WHERE id = v_students[i];
    END LOOP;

    -- =================================================================
    -- 11) Troféus automáticos + conquistas (alunos com troféus)
    -- =================================================================
    FOR i IN 1..4 LOOP
        v_id := gen_random_uuid();
        INSERT INTO trophies (id, academy_id, technique_id, name, start_date, end_date, target_count, award_kind, min_reward_level_to_unlock, max_count_per_opponent)
        VALUES (v_id, v_academy, v_tech[v_trophy_techidx[i]], v_trophy_names[i],
            date_trunc('month', v_today)::date, v_today + 30, v_trophy_target[i], 'trophy', 0, 3);
        v_trophy := array_append(v_trophy, v_id);
    END LOOP;

    FOR i IN 1..12 LOOP
        cnt := 1 + floor(random() * 2)::int;   -- 1 ou 2 troféus
        t1 := 1 + floor(random() * 4)::int;
        INSERT INTO user_trophy_earned (id, user_id, trophy_id, tier, earned_at)
        VALUES (gen_random_uuid(), v_students[i], v_trophy[t1], v_tiers[((i - 1) % 3) + 1],
            v_now - make_interval(days => (1 + floor(random() * 20))::int));
        IF cnt = 2 THEN
            t2 := 1 + floor(random() * 4)::int;
            WHILE t2 = t1 LOOP t2 := 1 + floor(random() * 4)::int; END LOOP;
            INSERT INTO user_trophy_earned (id, user_id, trophy_id, tier, earned_at)
            VALUES (gen_random_uuid(), v_students[i], v_trophy[t2], v_tiers[(i % 3) + 1],
                v_now - make_interval(days => (1 + floor(random() * 20))::int));
        END IF;
    END LOOP;

    -- =================================================================
    -- 12) Medalhas manuais (templates, campeonato, concessões)
    --     Protegido: pulado se as tabelas não existirem neste banco.
    -- =================================================================
    IF to_regclass('public.academy_trophy_templates') IS NOT NULL
       AND to_regclass('public.academy_championship_events') IS NOT NULL
       AND to_regclass('public.academy_trophy_awards') IS NOT NULL THEN

        v_tpl_destaque := gen_random_uuid();
        INSERT INTO academy_trophy_templates (id, academy_id, name, description, icon, color, trophy_type, created_by)
        VALUES (v_tpl_destaque, v_academy, 'Aluno Destaque do Mês', 'Reconhecimento ao aluno mais dedicado do mês.', 'star', '#FFD700', 'custom', v_prof);

        v_tpl_disc := gen_random_uuid();
        INSERT INTO academy_trophy_templates (id, academy_id, name, description, icon, color, trophy_type, created_by)
        VALUES (v_tpl_disc, v_academy, 'Disciplina de Ferro', 'Presença impecável nos treinos.', 'shield', '#C0C0C0', 'custom', v_prof);

        v_tpl_medal := gen_random_uuid();
        INSERT INTO academy_trophy_templates (id, academy_id, name, description, icon, color, trophy_type, created_by)
        VALUES (v_tpl_medal, v_academy, 'Medalha de Campeonato', 'Medalha conquistada em campeonato externo.', 'medal', '#CD7F32', 'championship', v_prof);

        v_champ := gen_random_uuid();
        INSERT INTO academy_championship_events (id, academy_id, name, location, event_date, created_by)
        VALUES (v_champ, v_academy, 'Copa Octogrip 2026', 'São Paulo - SP', v_today - 15, v_prof);

        FOR i IN 13..20 LOOP
            IF ((i - 13) % 2) = 0 THEN
                INSERT INTO academy_trophy_awards (id, template_id, user_id, awarded_by, championship_event_id, medal_type, note)
                VALUES (gen_random_uuid(), v_tpl_medal, v_students[i], v_prof, v_champ,
                    (ARRAY['gold','silver','bronze','participation'])[((i - 13) % 4) + 1], 'Pódio na categoria adulto.');
            ELSE
                INSERT INTO academy_trophy_awards (id, template_id, user_id, awarded_by, medal_type, note)
                VALUES (gen_random_uuid(),
                    CASE WHEN random() < 0.5 THEN v_tpl_destaque ELSE v_tpl_disc END,
                    v_students[i], v_prof,
                    (ARRAY['gold','silver','bronze'])[1 + floor(random() * 3)::int], 'Concedido pelo professor.');
            END IF;
        END LOOP;
    ELSE
        RAISE NOTICE 'Tabelas de medalhas manuais não existem neste banco — etapa de medalhas pulada.';
    END IF;

    -- =================================================================
    -- 13) Metas coletivas
    -- =================================================================
    INSERT INTO collective_goals (id, academy_id, technique_id, target_count, start_date, end_date)
    VALUES (gen_random_uuid(), v_academy, v_tech[10], 100, v_week_start, v_week_start + 6);
    INSERT INTO collective_goals (id, academy_id, technique_id, target_count, start_date, end_date)
    VALUES (gen_random_uuid(), v_academy, v_tech[3], 50, v_week_start, v_week_start + 6);

    -- =================================================================
    -- 14) Parceiros
    -- =================================================================
    INSERT INTO partners (id, academy_id, name, description, url, logo_url, button_label, highlight_on_login) VALUES
        (gen_random_uuid(), v_academy, 'Loja Tatame Forte', 'Kimonos e acessórios.', 'https://exemplo.com.br', 'https://placehold.co/120x120/png', 'Saiba mais', true),
        (gen_random_uuid(), v_academy, 'Suplementos Pro', 'Whey e creatina com desconto.', 'https://exemplo.com.br', 'https://placehold.co/120x120/png', 'Saiba mais', false),
        (gen_random_uuid(), v_academy, 'Fisio Esportiva', 'Recuperação para atletas.', 'https://exemplo.com.br', 'https://placehold.co/120x120/png', 'Saiba mais', false);

    -- =================================================================
    -- 15) Vídeos de treinamento
    -- =================================================================
    INSERT INTO training_videos (id, title, youtube_url, points_per_day, is_active, order_index, academy_id, created_by_id) VALUES
        (gen_random_uuid(), 'Aquecimento para o treino', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 10, true, 0, v_academy, v_prof),
        (gen_random_uuid(), 'Drills de passagem de guarda', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 10, true, 1, v_academy, v_prof),
        (gen_random_uuid(), 'Mobilidade de quadril', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 10, true, 2, v_academy, v_prof);

    -- =================================================================
    -- 16) Marketplace (protegido)
    -- =================================================================
    IF to_regclass('public.academy_marketplace_items') IS NOT NULL THEN
        INSERT INTO academy_marketplace_items (id, academy_id, title, description, price_cents, currency, image_url, whatsapp_phone, sort_order, is_active, created_by_id) VALUES
            (gen_random_uuid(), v_academy, 'Kimono Octogrip A2', 'Kimono trançado, branco, A2.', 35000, 'BRL', 'https://placehold.co/400x400/png', '5511999990001', 0, true, v_prof),
            (gen_random_uuid(), v_academy, 'Faixa Roxa A3', 'Faixa nova, lacrada.', 9000, 'BRL', 'https://placehold.co/400x400/png', '5511999990002', 1, true, v_prof),
            (gen_random_uuid(), v_academy, 'Rashguard Manga Longa', 'Rashguard preto, tamanho M.', 12000, 'BRL', 'https://placehold.co/400x400/png', '5511999990003', 2, true, v_prof);
    ELSE
        RAISE NOTICE 'Tabela academy_marketplace_items não existe — etapa de marketplace pulada.';
    END IF;

    -- =================================================================
    -- 17) Presença (sessões de chamada + registros)
    -- =================================================================
    FOREACH dday IN ARRAY ARRAY[1, 3] LOOP
        v_sess := gen_random_uuid();
        INSERT INTO attendance_sessions (id, academy_id, created_by_user_id, status, title, starts_at, ends_at, expires_at)
        VALUES (v_sess, v_academy, v_prof, 'closed',
            CASE WHEN dday = 1 THEN 'Treino Gi' ELSE 'Treino No-Gi' END,
            v_now - make_interval(days => dday, hours => 2),
            v_now - make_interval(days => dday, hours => 1),
            v_now - make_interval(days => dday, hours => 1));
        npres := 10 + floor(random() * 7)::int;   -- 10..16
        FOR r IN SELECT g AS idx FROM generate_series(1, 25) AS g ORDER BY random() LIMIT npres LOOP
            INSERT INTO attendance_records (id, session_id, user_id, checked_in_at, method, face_recognition, added_manually)
            VALUES (gen_random_uuid(), v_sess, v_students[r.idx],
                (v_now - make_interval(days => dday, hours => 2)) + make_interval(mins => floor(random() * 30)::int),
                'qr', false, false);
        END LOOP;
    END LOOP;

    -- =================================================================
    -- 18) Notificações in-app
    -- =================================================================
    FOR i IN 1..14 LOOP
        INSERT INTO notifications (id, user_id, type, title, body, read)
        VALUES (gen_random_uuid(), v_students[i], 'level_up', 'Você subiu de nível! 🎉',
            'Parabéns, ' || split_part(v_names[i], ' ', 1) || '! Continue treinando para subir ainda mais.',
            random() < 0.5);
        IF random() < 0.5 THEN
            INSERT INTO notifications (id, user_id, type, title, body, read)
            VALUES (gen_random_uuid(), v_students[i], 'trophy_earned', 'Novo troféu conquistado! 🏆',
                'Você desbloqueou um troféu da academia.', false);
        END IF;
    END LOOP;

    -- =================================================================
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Academia demo criada: % (slug=demo-octogrip)', v_academy;
    RAISE NOTICE '  alunos .............. 25';
    RAISE NOTICE '  professores ......... 2 (+ gerente)';
    RAISE NOTICE '  tecnicas/posicoes ... %', array_length(v_tech, 1);
    RAISE NOTICE '  trofeus automaticos . 4 (12 alunos premiados)';
    RAISE NOTICE '  senha de acesso ..... Demo@1234';
    RAISE NOTICE '  login gerente ....... gerente@demo.octogrip.com.br';
    RAISE NOTICE '  login professor ..... professor@demo.octogrip.com.br';
    RAISE NOTICE '  login aluno (ex.) ... aluno01@demo.octogrip.com.br';
    RAISE NOTICE '====================================================';
END $$;
