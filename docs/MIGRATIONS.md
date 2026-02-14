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

---

## Notas

- **Migration 009:** missions passou de `lesson_id` para `technique_id`; mission_usages passou de `lesson_id` para `mission_id`.
- **Migrations 010-011:** academias podem ter até 3 técnicas semanais (Missão 1, 2, 3).
