# Funcionalidades implementadas

Documento único com todas as funcionalidades do **backend (AppBaby)** e do **app Flutter (bjj_app)** até o momento.

---

## Backend (AppBaby) — FastAPI + PostgreSQL

### Infraestrutura

- **Stack:** FastAPI, PostgreSQL, SQLAlchemy, Docker, docker-compose
- **Execução:** `docker compose up` sobe API (porta 8000) e Postgres (5432)
- **Documentação:** Swagger em `/docs`
- **CORS:** Habilitado para o app Flutter (web/mobile)
- **Config:** Variáveis em `.env` (pydantic-settings)

### Modelos (SQLAlchemy)

| Modelo | Descrição |
|--------|-----------|
| **User** | Usuário (email, name); UUID como PK |
| **Position** | Posição do jiu-jitsu (name, slug, description) |
| **Technique** | Técnica: de uma Position para outra (from_position_id, to_position_id) |
| **Lesson** | Aula vinculada a uma Technique (title, slug, video_url, order_index) |
| **LessonProgress** | Conclusão de lição por usuário (user_id, lesson_id, completed_at); constraint única (user, lesson) |
| **TrainingFeedback** | Dificuldade em posição (user_id, position_id, difficulty_level, note) |

- PKs em **UUID**; timestamps **created_at** e **updated_at** (UUIDMixin)
- Preparado para **Alembic** (migrations)

### Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/health` | Health check simples |
| GET | `/health/db` | Health check + conexão com PostgreSQL |
| GET | `/lessons` | Lista aulas |
| GET | `/mission_today` | Missão do dia (título, video_url, técnica com posições) |
| POST | `/lesson_complete` | Registrar conclusão de lição (user_id, lesson_id); evita duplicata (409) |
| POST | `/training_feedback` | Registrar dificuldade em posição (user_id, position_id, observation opcional) |

- Validação de body (Pydantic); 404 para recurso não encontrado; 409 para conclusão duplicada
- Exceções de domínio em `app/core/exceptions`; mapeamento para HTTP via exception handlers

### Arquitetura

- **Camadas:** routes → services → models
- **Schemas:** Request/response em Pydantic
- **Routers:** Agregados em `app/routes/router.py`
- **Seed:** `docker compose exec api python -m app.scripts.seed` — 1 usuário, 2 posições, 1 técnica, 1 lição

---

## App Flutter (bjj_app)

### Estrutura

- **Pastas:** `screens/`, `services/`, `models/`
- **Tema:** Estilo Duolingo (`app_theme.dart`) — verde #58CC02, fundo claro, cards arredondados, botões em destaque

### Modelos

- **Mission:** lessonTitle, videoUrl, technique (TechniqueInfo)
- **TechniqueInfo:** name, slug, fromPositionName, toPositionName
- `fromJson` / `toJson` alinhados à API

### Serviços

- **MissionService**
  - `getMissionToday()` → `MissionLoadResult` (mission + fromCache)
  - Requisição GET `/mission_today`; em sucesso grava JSON no **SharedPreferences**
  - Em falha (rede/API), tenta **cache local**; se houver, retorna missão com `fromCache: true`
  - Sem cache → lança `MissionServiceException`

### Telas

| Tela | Funcionalidade |
|------|----------------|
| **HomeScreen** | Carrega missão ao iniciar; loading; exibe card (título + descrição da técnica); botão **COMEÇAR**; em erro, mensagem + **Tentar novamente**; se dados vierem do cache, mostra aviso **"Modo offline"** |
| **LessonScreen** | Recebe `Mission` por parâmetro; exibe título; placeholder de vídeo ("Vídeo em breve"); botão **CONCLUIR** (volta para a Home) |

### Navegação

- **Home** → (COMEÇAR) → **LessonScreen** → (CONCLUIR) → **Home**
- `Navigator.push` / `Navigator.pop` com `MaterialPageRoute`

### Offline (cache)

- Após carregar a missão com sucesso uma vez, o JSON fica salvo localmente
- Sem internet ou API indisponível: app usa última missão em cache e exibe **"Modo offline"**
- Navegação (COMEÇAR / CONCLUIR) funciona normalmente com dados em cache

### Testes

- Teste de widget: app inicia com HomeScreen e título "Missão do dia"
- Execução: `flutter test`

---

## Resumo rápido

| Área | O que está pronto |
|------|-------------------|
| **Backend** | API REST, modelos, missão do dia, conclusão de lição, feedback de treino, seed, CORS, exceções centralizadas |
| **App** | Tela inicial com missão (online/offline), aviso modo offline, tela de lição (placeholder de vídeo), navegação, cache com SharedPreferences |
