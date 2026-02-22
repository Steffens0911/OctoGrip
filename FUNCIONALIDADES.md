# Funcionalidades implementadas

Documento único com todas as funcionalidades do **backend (bjj_app)** e do **app Flutter (bjj_app)** até o momento.

---

## Backend (bjj_app) — FastAPI + PostgreSQL

### Infraestrutura

- **Stack:** FastAPI, PostgreSQL, SQLAlchemy, Docker, docker-compose
- **Execução:** `docker compose up` sobe API (porta 8000) e Postgres (5432)
- **Documentação:** Swagger em `/docs`
- **CORS:** Habilitado para o app Flutter (web/mobile)
- **Config:** Variáveis em `.env` (pydantic-settings)

### Modelos (SQLAlchemy)

| Modelo | Descrição |
|--------|-----------|
| **User** | Usuário (email, name, academy_id opcional); UUID como PK |
| **Academy** | Academia (name, slug, weekly_theme); 3 técnicas semanais (weekly_technique_id, weekly_technique_2_id, weekly_technique_3_id) para Missão 1, 2, 3 (A-01, A-02, A-03) |
| **Position** | Posição do jiu-jitsu (name, slug, description) |
| **Technique** | Técnica: de uma Position para outra (from_position_id, to_position_id) |
| **Lesson** | Aula vinculada a uma Technique (title, slug, video_url, order_index) |
| **LessonProgress** | Conclusão de lição por usuário (user_id, lesson_id, completed_at); constraint única (user, lesson) |
| **MissionUsage** | Conclusão de missão (user_id, mission_id, usage_type: before_training \| after_training); constraint única (user, mission) |
| **TrainingFeedback** | Dificuldade em posição (user_id, position_id, difficulty_level, note) |

- PKs em **UUID**; timestamps **created_at** e **updated_at** (UUIDMixin)
- Preparado para **Alembic** (migrations)

### Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/health` | Health check simples |
| GET | `/health/db` | Health check + conexão com PostgreSQL |
| GET | `/lessons` | Lista aulas |
| GET | `/positions` | Lista posições (para reportar dificuldade no app) |
| GET | `/mission_today` | Missão do dia (título, video_url, técnica com posições); `already_completed` indica se já concluiu |
| GET | `/mission_today/week` | 3 missões semanais (Missão 1, Missão 2, Missão 3) por nível/academia |
| GET | `/mission_usages/history` | Histórico de missões concluídas (user_id, limit) |
| GET | `/lesson_complete/status` | Verifica se lição já foi concluída (user_id, lesson_id) |
| POST | `/mission_complete` | Conclusão por missão (user_id, mission_id, usage_type: before_training \| after_training); 409 se já concluiu |
| GET | `/metrics/usage` | Métricas de uso (totais, últimos 7 dias, % antes do treino) |
| POST | `/lesson_complete` | Registrar conclusão de lição (user_id, lesson_id); evita duplicata (409) |
| POST | `/training_feedback` | Registrar dificuldade em posição (user_id, position_id, observation opcional) |

#### Seção Academia (CRUD e relatórios)

Ver documentação detalhada em **[docs/ACADEMIAS.md](docs/ACADEMIAS.md)**.

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/academies` | Lista academias |
| POST | `/academies` | Criar academia (body: name, slug opcional) |
| GET | `/academies/{id}` | Detalhe de uma academia |
| PATCH | `/academies/{id}` | Atualizar academia (body: name?, slug?, weekly_theme?) |
| DELETE | `/academies/{id}` | Excluir academia |
| GET | `/academies/{id}/ranking` | Ranking interno (period_days, limit) |
| GET | `/academies/{id}/difficulties` | Posições mais reportadas como difíceis |
| GET | `/academies/{id}/report/weekly` | Relatório semanal (year, week opcionais) |
| GET | `/academies/{id}/report/weekly/csv` | Relatório semanal em CSV |
| GET | `/missions` | Lista missões (academy_id, limit opcionais) |
| GET | `/missions/{id}` | Detalhe de uma missão |
| POST | `/missions` | Criar missão (lesson_id, start_date, end_date, level, theme?, academy_id?) |
| PATCH | `/missions/{id}` | Atualizar missão (campos parciais) |
| DELETE | `/missions/{id}` | Excluir missão |
| GET | `/missions/panel` | Painel web HTML para criar missão em 10s |

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

### Conclusão de missão e lição (aluno)

- **Botão "Concluir"**: Ao concluir (missão ou lição), a API retorna 409 se já concluído; o app troca o botão por **"Missão concluída"** ou **"Lição concluída"** e desabilita.
- **Conclusão conhecida ao abrir**: Se a lição/missão já estiver concluída ao abrir a tela (via `alreadyCompleted` ou `GET /lesson_complete/status`), o botão já aparece desabilitado com texto de conclusão.
- **Diálogo "Antes/Depois do treino"**: Ao concluir missão, o app exibe diálogo perguntando **"Quando você visualizou?"** com opções **Antes do treino** ou **Depois do treino**; o valor é enviado em `POST /mission_complete` como `usage_type`.

### Três missões semanais (aluno)

- **StudentHomeScreen**: Exibe 3 cards — **Missão 1**, **Missão 2**, **Missão 3** — cada um com a missão do slot (ou vazio se não houver). Rótulos sem dias (antes era "Seg–Ter", etc.).
- **Professor (AcademyDetailScreen)**: Pode definir até 3 técnicas semanais por academia; cada slot (1, 2, 3) mapeia para seg-ter, qua-qui, sex-dom. Se só técnica 1 estiver preenchida, missão aparece apenas no slot 1.

### Meu progresso

- **Data sem horário**: A tela "Meu progresso" exibe apenas a **data** (ex.: 12/02/2025), sem horário, nas entradas do histórico.

### Área do professor (Perfil → Área do professor)

O professor acessa pelo app (Perfil → **Área do professor**) e pode:

1. **Missões (aba Missões)**
   - **Listar** todas as missões (período, nível, tema).
   - **Criar** missão: escolher lição (GET /lessons), data início e fim (YYYY-MM-DD), nível (beginner/intermediate/advanced), tema opcional, academia opcional. Botão + (FAB).
   - **Editar** e **Excluir** por toque no card ou menu (⋮).
   - Estado vazio: mensagem e orientação para criar a primeira missão.

2. **Academias (aba Academias)**
   - **Listar** academias; toque abre o detalhe.
   - **Detalhe da academia:**
     - **Missões semanais:** 3 dropdowns para selecionar técnica (Missão 1, Missão 2, Missão 3). Se só Missão 1 estiver preenchida, aparece missão apenas no slot 1.
     - **Tema da semana:** campo de texto + **Salvar tema** (PATCH /academies/{id}).
     - **Ranking (últimos 30 dias):** lista legível (posição, nome, conclusões).
     - **Dificuldades reportadas:** posições mais marcadas como difíceis (nome, quantidade de reportes).
     - **Relatório semanal:** período da semana, total de conclusões, ativos e lista do ranking da semana.
   - Estado vazio: mensagem quando não há academias cadastradas.

### Outras telas do app

- **Biblioteca de lições** (aba Lições): lista GET /lessons; toque abre a lição como LessonScreen (e envia POST /lesson_complete ao concluir).
- **Galeria de troféus e medalhas:** lista em cards com filtros (tier, tipo), switch "Galeria visível para outros" (PATCH /auth/me), "Indicar adversário". Ícone da AppBar **"Ver como estante"** abre a visão gamificada (prateleiras, glow ouro, modal de detalhes). Ver [docs/TROPHY_SHELF.md](docs/TROPHY_SHELF.md).
- **Reportar dificuldade** (Perfil): GET /positions, escolha da posição e observação opcional; POST /training_feedback.
- **Histórico de missões** (Progresso): seção "Últimas missões concluídas" com GET /mission_usages/history.
- **Métricas de uso** (Perfil): GET /metrics/usage com totais e % antes/depois do treino.

### Testes

- Teste de widget: app inicia com HomeScreen e título "Missão do dia"
- Execução: `flutter test`

---

## Resumo rápido

| Área | O que está pronto |
|------|-------------------|
| **Backend** | API REST, modelos, missão do dia, 3 missões semanais, conclusão de lição/missão (com usage_type), lesson_complete/status, feedback de treino, positions, mission_usages/history, metrics/usage; área professor: academies (3 técnicas semanais, tema, ranking, difficulties, report/weekly), missions CRUD; seed com academia e missões |
| **App** | Tela inicial com 3 missões semanais, lição (botão concluído desabilitado quando já feito), diálogo antes/depois do treino ao concluir missão, biblioteca de lições, **galeria de troféus/medalhas** (lista + estante gamificada), progresso com histórico (data sem horário), reportar dificuldade, métricas; **Área do professor:** missões (CRUD) e academias (3 missões semanais, tema, ranking, dificuldades, relatório semanal) |
