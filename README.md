# JJB API — MVP SaaS Jiu-Jitsu

Backend inicial para ensino de jiu-jitsu para iniciantes: FastAPI, PostgreSQL, SQLAlchemy e Docker.

## Pré-requisitos

- Docker e Docker Compose

## Subir o projeto

```bash
docker compose up --build
```

- **API:** http://localhost:8000  
- **Docs:** http://localhost:8000/docs  
- **PostgreSQL:** localhost:5432 (user `jjb`, db `jjb_db`)

## Seed (dados de teste)

Para popular o banco com 1 usuário, 2 posições, 1 técnica e 1 lição (e testar os endpoints no /docs):

```bash
docker compose exec api python -m app.scripts.seed
```

O script imprime os IDs para usar no body dos POSTs. Rodar localmente (com Postgres acessível): `python -m app.scripts.seed`.

## Endpoints

| Método | Endpoint           | Descrição                    |
|--------|--------------------|-------------------------------|
| GET    | /health            | Health check                  |
| GET    | /health/db         | Health check + banco          |
| GET    | /lessons           | Lista aulas                   |
| GET    | /mission_today     | Missão do dia                 |
| POST   | /lesson_complete   | Registrar conclusão de lição  |
| POST   | /training_feedback | Registrar dificuldade (posição) |

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

Detalhes em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Variáveis de ambiente

Copie `.env.example` para `.env` e ajuste se precisar. O `docker-compose.yml` já usa valores padrão (jjb/jjb_secret/jjb_db).

## Rodar só a API (sem Docker)

```bash
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
# Postgres precisa estar rodando (ex.: docker compose up postgres -d)
# Exporte DATABASE_URL=postgresql://jjb:jjb_secret@localhost:5432/jjb_db
uvicorn app.main:app --reload
```
