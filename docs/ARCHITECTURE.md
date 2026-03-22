# Arquitetura do backend

## Visão geral

- **Camadas:** routes → services → models. Schemas (Pydantic) definem contrato de entrada/saída.
- **Exceções:** domínio em `app/core/exceptions`; mapeamento para HTTP via exception handlers em `main.py`.
- **Routers:** agregados em `app/routes/router.py`; `main.py` inclui apenas `api_router`.

## Estrutura de pastas

```
app/
├── main.py              # App FastAPI, lifespan, exception handlers, include api_router
├── config.py            # Settings (pydantic-settings)
├── database.py          # AsyncEngine, AsyncSessionLocal, Base, async get_db
├── core/
│   ├── exceptions.py    # AppError, NotFoundError, UserNotFoundError, AlreadyCompletedError, etc.
│   └── __init__.py
├── models/              # SQLAlchemy (entidades e Base)
├── schemas/             # Pydantic (request/response)
├── services/            # Regras de negócio e acesso a dados (recebem Session)
└── routes/
    ├── router.py           # Agregação de todos os routers (api_router)
    ├── admin.py            # Painel HTML (missions/panel)
    ├── health.py
    ├── academies.py        # CRUD academias, ranking, difficulties, report
    ├── users.py
    ├── lessons.py
    ├── techniques.py
    ├── positions.py
    ├── missions.py         # CRUD missões
    ├── mission.py          # mission_today, mission_today/week
    ├── mission_complete.py # POST conclusão por missão
    ├── mission_usages.py   # sync, history
    ├── lesson_complete.py  # status, POST conclusão de lição
    ├── training_feedback.py
    └── metrics.py
```

## Fluxo de uma requisição

1. **Route:** valida body/query (Pydantic), chama service, retorna schema.
2. **Service:** valida regras, acessa models, levanta exceções de `core.exceptions` em caso de erro.
3. **Exception handler:** captura `AppError` (e subclasses), retorna `JSONResponse` com `status_code` e `detail`.

Novas exceções de domínio devem herdar de `AppError` (ou `NotFoundError` para 404) e definir `status_code`; o handler já as converte em resposta HTTP.

## Convenções

- **Services:** recebem `db: AsyncSession` como primeiro argumento; são `async def`; não importam FastAPI.
- **Routes:** são `async def`; apenas orquestram (Depends(get_db), `await` chamada ao service, return response); não contêm try/except para exceções de domínio.
- **Database:** uso de `await db.execute(select(...))` em vez de `db.query()`; `await db.commit()` e `await db.refresh()`.
- **IDs:** UUID como PK em todos os models; uso de `UUIDMixin` para id, created_at, updated_at.
- **Config:** variáveis em `app/config.py` via `pydantic_settings`; uso de `.env` em desenvolvimento.

## Modelos principais

| Modelo | Descrição |
|--------|-----------|
| User, Academy, Professor | Usuários vinculados a academia |
| Position, Technique, Lesson | Conteúdo (posições, técnicas, lições) |
| Mission | Missão = técnica + período + academia |
| LessonProgress | Conclusão de lição (user, lesson) |
| MissionUsage | Conclusão de missão (user, mission, usage_type) |
| TrainingFeedback | Dificuldade reportada em posição |

## Melhorias arquiteturais concluídas

### P0: Segurança e configuração
- ✅ **JWT Secret:** Configuração via variável de ambiente com aviso para produção
- ✅ **CORS:** Configurável via `CORS_ORIGINS` (JSON); em dev, lista vazia + `allow_origin_regex` para `localhost`/`127.0.0.1` com qualquer porta (Flutter Web). `["*"]` é ignorado (incompatível com `Authorization`).
- ✅ **Rate Limiting:** Implementado com `slowapi` no endpoint de login (`LOGIN_RATE_LIMIT`)

### P1: Migrações de banco de dados
- ✅ **Versionamento:** Sistema de tracking de migrações SQL via tabela `_migrations`
- ✅ **Idempotência:** Migrações executadas apenas uma vez, detectadas automaticamente
- ✅ **Estrutura:** Migrações SQL em `migrations/` numeradas sequencialmente

### P2: Frontend (Flutter)
- ✅ **State Management:** Adoção de Riverpod/Provider para gerenciamento de estado
- ✅ **ViewModels:** Extração de lógica de negócio para ViewModels separados
- ✅ **Consolidação de serviços:** `AcademyService` e `ProfessorService` consolidados dentro de `ApiService`

### P3: Backend assíncrono
- ✅ **asyncpg:** Driver PostgreSQL assíncrono substituindo psycopg2
- ✅ **SQLAlchemy async:** Migração completa para `AsyncSession` e `await db.execute(select(...))`
- ✅ **Rotas assíncronas:** Todas as rotas convertidas para `async def`
- ✅ **Services assíncronos:** Todos os services atualizados para padrão assíncrono
- ✅ **Pool de conexões:** Configurável via `DB_POOL_SIZE` e `DB_MAX_OVERFLOW`

### P4: Testes e CI/CD
- ✅ **Testes:** 61 testes pytest cobrindo rotas principais (health, auth, users, academies, CRUD, executions)
- ✅ **Fixtures async:** PostgreSQL real com `pytest-asyncio` e event loop session-scoped
- ✅ **CI/CD:** GitHub Actions com 3 jobs (test, lint, docker build)
- ✅ **Cobertura:** Testes de integração para fluxos críticos (login, CRUD, execuções)

### P5: Otimização de Performance

#### Backend - Otimizações de Banco de Dados
- ✅ **N+1 Queries corrigidas:** `reset_academy_missions` otimizado para buscar todos os usuários de uma vez
- ✅ **Agregação SQL:** Uso de `func.sum()` em vez de carregar todos os registros na memória
- ✅ **Índices compostos:** Adicionados 6 índices compostos nas tabelas principais:
  - `MissionUsage`: `(user_id, mission_id)` e `(user_id, completed_at)`
  - `LessonProgress`: `(user_id, completed_at)`
  - `TechniqueExecution`: `(user_id, mission_id, status)` e `(opponent_id, status)`
  - `Mission`: `(academy_id, level, slot_index, is_active)`
- ✅ **Queries otimizadas:** `get_academy_ranking` removida query extra de nomes; `get_points_log` com projeção direta
- ✅ **Paginação:** Adicionada paginação adequada em `list_users` e `get_points_log` com `offset` e `limit`

#### Frontend - Otimizações de Renderização
- ✅ **ListView.builder:** Substituído `ListView` por `ListView.builder` em `library_screen.dart` e `academy_panel_screen.dart`
- ✅ **Debounce:** Adicionado debounce de 300ms em campos de busca (`user_list_screen.dart` e `library_screen.dart`)
- ✅ **Otimização de setState:** Agrupamento de múltiplos `setState` em `student_home_screen.dart`
- ✅ **Paginação:** Implementada paginação com botão "Carregar mais" em listas grandes (`user_list_screen.dart` e `library_screen.dart`)

## Evolução futura

- **Autenticação:** middleware ou dependencies que resolvem `user_id` a partir do token; passar `user_id` para services.
- **Migrations:** desativar `create_all` no lifespan e usar apenas Alembic.
- **Features por domínio:** se o projeto crescer, considerar `app/features/lessons/`, `app/features/mission/` com route + service + schema por feature.
