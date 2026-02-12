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
├── database.py          # Engine, SessionLocal, Base, get_db
├── core/
│   ├── exceptions.py    # AppError, NotFoundError, UserNotFoundError, AlreadyCompletedError, etc.
│   └── __init__.py
├── models/              # SQLAlchemy (entidades e Base)
├── schemas/             # Pydantic (request/response)
├── services/            # Regras de negócio e acesso a dados (recebem Session)
└── routes/
    ├── router.py        # Agregação de todos os routers (api_router)
    ├── health.py
    ├── lessons.py
    ├── mission.py
    ├── lesson_complete.py
    └── training_feedback.py
```

## Fluxo de uma requisição

1. **Route:** valida body/query (Pydantic), chama service, retorna schema.
2. **Service:** valida regras, acessa models, levanta exceções de `core.exceptions` em caso de erro.
3. **Exception handler:** captura `AppError` (e subclasses), retorna `JSONResponse` com `status_code` e `detail`.

Novas exceções de domínio devem herdar de `AppError` (ou `NotFoundError` para 404) e definir `status_code`; o handler já as converte em resposta HTTP.

## Convenções

- **Services:** recebem `db: Session` como primeiro argumento; não importam FastAPI.
- **Routes:** apenas orquestram (Depends(get_db), chamada ao service, return response); não contêm try/except para exceções de domínio.
- **IDs:** UUID como PK em todos os models; uso de `UUIDMixin` para id, created_at, updated_at.
- **Config:** variáveis em `app/config.py` via `pydantic_settings`; uso de `.env` em desenvolvimento.

## Evolução futura

- **Autenticação:** middleware ou dependencies que resolvem `user_id` a partir do token; passar `user_id` para services.
- **Migrations:** desativar `create_all` no lifespan e usar apenas Alembic.
- **Features por domínio:** se o projeto crescer, considerar `app/features/lessons/`, `app/features/mission/` com route + service + schema por feature.
