# Hot paths de banco (PostgreSQL + SQLAlchemy async)

Documentação de consultas de maior custo e colunas usadas em filtros, para manutenção de índices e cache.

## Ranking e relatórios de academia

- **`get_academy_ranking` / `get_academy_weekly_report`** ([`app/services/academy_service.py`](../app/services/academy_service.py))
  - `lesson_progress`: join `User` → `User.academy_id`, `LessonProgress.completed_at` em intervalo.
  - `mission_usages`: join `User` → `User.academy_id`, `MissionUsage.completed_at` em intervalo.
  - `technique_executions`: join `User` → `User.academy_id`, `status = 'confirmed'`, tempo = `coalesce(confirmed_at, created_at)` em intervalo.
  - Índices já existentes relevantes: `idx_technique_execution_user_status_confirmed`, FKs em `mission_usages`, `idx_lesson_progress_user_completed` (modelo).

## Presença (attendance)

- **`list_attendance_sessions` / `attendance_ranking` / `stats_students`** ([`app/services/attendance_service.py`](../app/services/attendance_service.py))
  - `attendance_sessions`: `academy_id`, `starts_at` (janelas), `created_by_user_id`, `status`.
  - `attendance_records`: `session_id`, `user_id`, `checked_in_at`; unique `(session_id, user_id)`.

## Métricas e relatórios (painel)

- **`get_usage_metrics` / `get_engagement_report` / `get_active_students_report` / `get_weekly_panel_logins_report`** ([`app/services/metrics_service.py`](../app/services/metrics_service.py))
  - `users`: `role`, `academy_id`, `last_login_at`.
  - `user_login_days`: `user_id`, `login_day` em intervalo.
  - `lesson_progress` / `mission_usages`: joins por `User.academy_id` e timestamps.

## Cache TTL aplicado (ver implementação)

- Prefixos em memória (`TTLCache`): `academy_analytics:`, `metrics_report:`, `attendance_ranking:`, `featured_global_partners:`.
- Invalidação de `academy_analytics` após conclusões que alteram contagens (lição, missão, execução confirmada, sync de usos).
- **`invalidate_academy_analytics_cache`** também chama **`invalidate_metrics_cache`** (limpa todo o prefixo `metrics_report:`), mantendo painéis coerentes com os mesmos eventos de escrita.

## Paginação da API (listagens)

- Teto global de **`limit`**: **50** por requisição (constante `app.core.list_pagination.MAX_LIST_LIMIT`).
- O viewer Flutter acumula páginas quando precisa da lista completa (ex.: `getAttendanceSessionRecordsAll`, `getUsersAll`, `getMissionUsagesHistoryAll`).

## Migration de índices incrementais

Ver [`migrations/067_add_performance_indexes.sql`](../migrations/067_add_performance_indexes.sql).
