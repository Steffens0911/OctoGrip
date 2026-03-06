# Migrações do banco de dados

Migrações SQL executadas manualmente na ordem numérica.

**Execução (exemplo):**
```bash
docker compose exec postgres psql -U jjb -d jjb_db -f /caminho/migrations/001_create_missions.sql
```

---

## Ordem das migrações

| # | Arquivo | Descrição |
|---|---------|-----------|
| 001 | create_missions | Tabela `missions` (lesson_id, start_date, end_date) |
| 002 | add_mission_level | Campo `level` em missions |
| 003 | add_mission_theme | Campo `theme` em missions |
| 004 | create_mission_usages | Tabela `mission_usages` (user, lesson, usage_type) |
| 005 | create_academies_and_user_link | Tabela `academies`; `users.academy_id` |
| 006 | add_mission_academy | `missions.academy_id` (missão por academia) |
| 007 | add_academy_weekly_theme | `academies.weekly_theme` |
| 008 | create_professors | Tabela `professors` |
| 009 | mission_technique_and_usage_mission | `missions.technique_id`; `mission_usages.mission_id` |
| 010 | academy_weekly_technique | `academies.weekly_technique_id` (Missão 1) |
| 011 | academy_weekly_techniques_2_and_3 | `academies.weekly_technique_2_id`, `weekly_technique_3_id` |
| 012 | technique_video_url | `techniques.video_url` (link YouTube) |
| 013 | user_graduation | `users.graduation` (faixa: white, blue, purple, brown, black) |
| 014 | technique_executions | Tabela `technique_executions` (gamificação: execução em adversário, confirmação, pontos) |
| 015 | collective_goals | Tabela `collective_goals` (meta coletiva semanal por técnica) |
| 016 | mission_lesson_id | `missions.lesson_id` (UUID, nullable, FK para `lessons`); backfill com 1ª lição da técnica |
| 017 | lesson_technique_base_points | `lessons.base_points`, `techniques.base_points` (Integer, default 10) |
| 018 | academy_visible_lesson | `academies.visible_lesson_id` (UUID, nullable, FK para `lessons`) |
| 019 | execution_lesson_id | `technique_executions.lesson_id` (nullable); `mission_id` nullable; CHECK um de mission_id ou lesson_id |
| 020 | mission_multiplier_academy_multipliers_points | `missions.multiplier`; `academies.weekly_multiplier_1/2/3`; `mission_usages.points_awarded` |
| 021 | mission_slot_index | `missions.slot_index` (0,1,2); `start_date`/`end_date` opcionais |
| 022 | user_points_adjustment | `users.points_adjustment` (ajuste manual de pontos por admin) |
| 033 | user_gallery_visible | `users.gallery_visible` (galeria de troféus visível ou privada para outros) |
| 034 | user_last_login_at | `users.last_login_at` (timestamp do último login bem-sucedido, usado em relatórios de engajamento) |
| 042 | trophy_min_points_to_unlock | `trophies.min_points_to_unlock` (pontos mínimos do aluno para desbloquear o troféu; 0 = todos) |
| 043 | trophy_min_graduation_to_unlock | `trophies.min_graduation_to_unlock` (faixa mínima: white, blue, purple, brown, black; NULL = todos) |

---

## Script manual: zerar posições, técnicas e missões

Para limpar todos os dados de posições, técnicas, lições e missões (e tabelas dependentes), execute **uma vez** o script (não é aplicado no startup):

```bash
docker compose exec -T postgres psql -U jjb -d jjb_db < scripts/zerar_posicoes_tecnicas_missoes.sql
```

Ou, com o arquivo já no container:

```bash
docker compose exec postgres psql -U jjb -d jjb_db -f /caminho/scripts/zerar_posicoes_tecnicas_missoes.sql
```

---

## Notas

- **Migration 009:** missions passou de `lesson_id` para `technique_id`; mission_usages passou de `lesson_id` para `mission_id`.
- **Migrations 010-011:** academias podem ter até 3 técnicas semanais (Missão 1, 2, 3).
- **Migration 016:** missão passa a referenciar uma lição específica; unifica conteúdo de missão e lição (título, vídeo, etc. vêm da lição quando `lesson_id` está preenchido).
- **Migrations 017-019:** pontuação base em lição/técnica; lição visível por academia; execução por lição (sem missão), com `mission_id` ou `lesson_id`.
- **Migration 020:** multiplicador por missão; multiplicadores por slot semanal da academia; pontos em MissionUsage ao concluir missão (multiplicador × faixa).
- **Migration 021:** missões da academia identificadas por `slot_index` (0, 1, 2); sem dependência de datas. Cada academia cria suas 3 missões; `start_date`/`end_date` opcionais (legado).
- **Migration 033:** preferência do usuário para exibir ou ocultar a galeria de troféus para outros; quando visível, outros veem apenas itens já conquistados.
- **Migration 034:** adiciona `users.last_login_at` para registrar o último login bem-sucedido. Relatórios de engajamento e alunos ativos usam este campo para definir quem é considerado "ativo" em uma janela de tempo.
- **Migration 042:** adiciona `trophies.min_points_to_unlock`. O gerente/professor define quantos pontos o aluno precisa para desbloquear cada troféu; 0 = todos podem competir. Troféus existentes recebem 0 (comportamento anterior mantido).
- **Migration 043:** adiciona `trophies.min_graduation_to_unlock`. Faixa mínima (white, blue, purple, brown, black) para o aluno poder competir pelo troféu; NULL = sem restrição. Desbloqueio exige pontos e faixa mínimos quando definidos.