# JJB API — MVP SaaS Jiu-Jitsu

Backend inicial para ensino de jiu-jitsu para iniciantes: FastAPI, PostgreSQL, SQLAlchemy e Docker.

## Pré-requisitos

- Docker e Docker Compose

## Subir todo o app (API + Postgres + Viewer)

```bash
docker compose up --build
```

Na primeira execução o build do **viewer** (Flutter web) pode levar alguns minutos. Depois:

| Serviço    | URL                          |
|-----------|------------------------------|
| **Viewer** (app web) | http://localhost:8080        |
| **API**    | http://localhost:8001        |
| **Docs**   | http://localhost:8001/docs   |
| **PostgreSQL** | localhost:5432 (user `jjb`, db `jjb_db`) |

Para subir só a API e o Postgres (sem o viewer):

```bash
docker compose up --build postgres api
```

Para subir API e Viewer (sem rebuild do Postgres):

```bash
docker compose up -d --build api viewer
```

### HTTPS na VPS (Caddy)

Com domínios apontando para a máquina, use o override que adiciona **Caddy** (TLS automático com Let’s Encrypt) na frente do viewer e da API:

1. No `.env`: `APP_DOMAIN` (app web), `API_DOMAIN` (API), `API_BASE_URL=https://<API_DOMAIN>`, `CORS_ORIGINS` com a origem `https://<APP_DOMAIN>`, além de `JWT_SECRET`, `POSTGRES_PASSWORD`, `ENVIRONMENT=production`, `SEED_ON_STARTUP=false`.
2. Suba tudo:

```bash
docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d --build
```

| Serviço | URL pública        |
|---------|--------------------|
| Viewer  | `https://$APP_DOMAIN` |
| API     | `https://$API_DOMAIN`  |

Configuração: `deploy/caddy/Caddyfile` e `docker-compose.caddy.yml`.

## Seed (dados de teste)

Para popular o banco com 1 usuário, 2 posições, 1 técnica e 1 lição (e testar os endpoints no /docs):

```bash
docker compose exec api python -m app.scripts.seed
```

O script imprime os IDs para usar no body dos POSTs. Rodar localmente (com Postgres acessível): `python -m app.scripts.seed`.

## Como usar como professor (CRUD de missões)

O **app Flutter (bjj_app)** é para **alunos**. O professor usa o **painel web** na própria API:

1. **Suba a API** (Docker ou local):
   ```bash
   docker compose up --build
   ```
   Ou local: `uvicorn app.main:app --reload` (com Postgres rodando).

2. **Abra no navegador** (Chrome, Edge, etc.):
   ```
   http://localhost:8001/missions/panel
   ```
   Se a API estiver em outra máquina/porta, use a mesma URL base (ex.: `http://192.168.1.10:8000/missions/panel`).

3. No painel você pode:
   - **Criar missão**: escolher lição, datas, nível, tema e academia (ou global), e clicar em "Criar missão".
   - A lista de **lições** e **academias** é carregada da API; as datas padrão são a semana atual.

4. **Listar / editar / excluir** missões pela **documentação interativa**:
   - Abra **http://localhost:8001/docs**
   - Use **GET /missions** para listar (opcional: `academy_id` para filtrar).
   - Use **GET /missions/{mission_id}** para ver uma missão.
   - Use **PATCH /missions/{mission_id}** para editar (envie só os campos que quer alterar).
   - Use **DELETE /missions/{mission_id}** para excluir.

Resumo: **professor = navegador em /missions/panel e /docs**; **aluno = app Flutter**.

## Endpoints

| Método | Endpoint           | Descrição                    |
|--------|--------------------|-------------------------------|
| GET    | /health            | Health check                  |
| GET    | /health/db         | Health check + banco          |
| GET    | /lessons           | Lista aulas                   |
| GET    | /mission_today     | Missão do dia                 |
| GET    | /mission_today/week | 3 missões semanais (Missão 1, 2, 3) |
| GET    | /academies/{id}    | Dados da academia             |
| PATCH  | /academies/{id}    | Atualizar academia (incl. 3 técnicas semanais) |
| GET    | /academies              | Lista academias         |
| GET    | /academies/{id}/ranking | Ranking interno (A-04)  |
| GET    | /academies/{id}/difficulties | Dificuldades (T-02) |
| GET    | /academies/{id}/report/weekly | Relatório semanal (T-03) |
| GET    | /academies/{id}/report/weekly/csv | Export CSV (T-03) |
| GET    | /missions               | Lista missões           |
| GET    | /missions/{id}          | Uma missão              |
| POST   | /missions               | Criar missão            |
| PATCH  | /missions/{id}          | Editar missão           |
| DELETE | /missions/{id}           | Excluir missão          |
| GET    | /missions/panel         | **Painel professor (web)** |
| POST   | /lesson_complete   | Registrar conclusão de lição  |
| GET    | /lesson_complete/status | Verifica se lição já foi concluída |
| POST   | /mission_complete  | Registrar conclusão de missão (usage_type: before_training \| after_training) |
| GET    | /mission_usages/history | Histórico de missões concluídas |
| POST   | /training_feedback | Registrar dificuldade (posição) |
| GET    | /metrics/usage     | Métricas de uso              |

**Documentação detalhada:** [docs/API.md](docs/API.md)

## Estrutura

```
app/
├── main.py           # FastAPI, lifespan, exception handlers, api_router
├── config.py         # Settings (env)
├── database.py       # Engine, Session, Base, get_db
├── core/
│   └── exceptions.py # Exceções de domínio (404, 409, etc.)
├── models/           # SQLAlchemy
├── schemas/          # Pydantic (request/response)
├── services/         # Lógica de negócio
└── routes/
    ├── router.py     # Agregação de todos os routers
    └── ...
```

**Documentação completa:** [docs/INDEX.md](docs/INDEX.md) | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Variáveis de ambiente

Copie `.env.example` para `.env` e ajuste se precisar. O `docker-compose.yml` já usa valores padrão (jjb/jjb_secret/jjb_db). Para o viewer, a URL da API no build é `API_BASE_URL` (padrão `http://localhost:8001`); se a API estiver em outro host/porta, defina no `.env` antes do `docker compose build`.

## Rodar só a API (sem Docker)

```bash
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
# Postgres precisa estar rodando (ex.: docker compose up postgres -d)
# Exporte DATABASE_URL=postgresql://jjb:jjb_secret@localhost:5432/jjb_db
uvicorn app.main:app --reload
```
