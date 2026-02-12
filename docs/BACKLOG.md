# Backlog — JJB (AppBaby + bjj_app)

Backlog de produto por fases e backlog técnico concluído.

---

## Legenda

| Status   | Significado |
|----------|-------------|
| **DONE**  | Entregue e em uso |
| **TODO** | A fazer |
| REF      | Referência (épico / tema) |

---

## Roadmap por fases

### FASE 1 — MVP VALIDADO *(você está aqui)*

**Objetivo:** provar que o app entra na rotina do treino.

#### REF — Produto núcleo

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| P-01 | DONE   | Missão do dia | App abre direto na missão |
| P-02 | DONE   | Lição simples | Vídeo (real ou placeholder) + descrição + concluir |
| P-03 | DONE   | Progresso básico | Missões concluídas salvas |
| P-04 | DONE   | Cache offline | Missão abre sem internet |
| P-05 | DONE   | Registro before/after treino | Uso armazenado localmente |
| P-06 | DONE   | Métricas backend básicas | Endpoint métricas usage |

#### REF — Estabilidade MVP

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| S-01 | DONE   | Logs estruturados | Logs claros em services |
| S-02 | DONE   | Timeout API | Falha de rede não trava app |
| S-03 | DONE   | Tratamento erro padrão | Mensagem amigável no app |
| S-04 | DONE   | Seed expandido | 10+ lições iniciante |

---

### FASE 1.5 — VALIDAÇÃO DE HÁBITO

**Objetivo:** confirmar uso recorrente antes de evoluir produto.

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| V-01 | DONE   | Métrica before_training | ≥50% usos antes do treino |
| V-02 | DONE   | Missão concluída semanalmente | ≥2x por usuário |
| V-03 | DONE   | Feedback qualitativo | Aluno cita missão no treino |

---

### FASE 2 — PRODUCT FIT (primeira versão real)

**Objetivo:** app começa a ser necessário para o treino.

#### REF — Missão inteligente (sem IA)

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| PF-01 | DONE | Missão por nível | beginner/intermediate |
| PF-02 | TODO | Missão semanal | Tema da semana |
| PF-03 | TODO | Repetição automática | Revisão após X dias |
| PF-04 | TODO | Missão baseada em feedback | Posição difícil priorizada |

#### REF — Experiência do usuário

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| UX-01 | TODO | Animação conclusão | Feedback visual consistente (mesma linguagem/resposta emocional) |
| UX-02 | TODO | Progresso visual faixa branca | Barra por grau |
| UX-03 | TODO | Tela missão clara em 1 segundo | Sem leitura longa |
| UX-04 | TODO | Tempo estimado da missão | 2–3 min visível |

#### REF — Backend produto

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| PB-01 | TODO | MissionUsage backend | Sync do uso local |
| PB-02 | TODO | Métricas de retenção | % before training |
| PB-03 | TODO | Histórico de missões | Últimas 7 missões |

---

### FASE 3 — ACADEMIAS (B2B)

**Objetivo:** app vira parte do método da academia.

#### REF — Academia

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| A-01 | TODO | Model Academy | Usuário vinculado |
| A-02 | TODO | Missão por academia | Override global |
| A-03 | TODO | Tema semanal academia | Professor define |
| A-04 | TODO | Ranking interno simples | Só academia |

#### REF — Professor

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| T-01 | TODO | Painel simples web | Criar missão em 10s |
| T-02 | TODO | Visualização dificuldades | Posições mais marcadas |
| T-03 | TODO | Export simples | Relatório semanal |

---

### FASE 4 — PRODUTO PROFISSIONAL

**Objetivo:** retenção longa (faixa azul continua usando).

#### REF — Evolução do jogo

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| G-01 | TODO | Mapa do jogo pessoal | Posições fortes/fracas |
| G-02 | TODO | Estatística de posições | Histórico |
| G-03 | TODO | Foco semanal manual | Usuário escolhe |

#### REF — Conteúdo escalável

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| C-01 | TODO | Lesson reutilizável (ferramenta) | Escolher lesson existente ao criar mission; sugerir reutilização; evitar duplicação |
| C-02 | TODO | Sequência de técnicas | Fluxo lógico |
| C-03 | TODO | Revisão automática | Spaced repetition |
| C-04 | TODO | Player de vídeo otimizado | Vídeo real na lição |

---

### FASE 5 — ESCALA (startup madura)

**Objetivo:** crescimento orgânico e defensável.

#### REF — Inteligência do sistema

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| AI-01 | TODO | Recomendações automáticas | Baseadas em uso |
| AI-02 | TODO | Plano semanal automático | Gerado pelo sistema |
| AI-03 | TODO | Ajuste dinâmico de dificuldade | Baseado em sucesso |

#### REF — Plataforma

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| PL-01 | TODO | Multi-esporte (estrutura) | Engine neutra |
| PL-02 | TODO | API pública academias | Integração futura |
| PL-03 | TODO | Histórico completo atleta | Longo prazo |

---

## Backlog técnico concluído

Itens já implementados (engenharia).

### Backend (AppBaby)

#### REF — Infraestrutura e base

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-01 | DONE   | Stack e execução | FastAPI + PostgreSQL + SQLAlchemy; Docker Compose sobe API (8000) e Postgres (5432) |
| B-02 | DONE   | Documentação da API | Swagger em `/docs`; CORS habilitado para o app |
| B-03 | DONE   | Configuração | Variáveis em `.env` (pydantic-settings); `config.py` |
| B-04 | DONE   | Arquitetura em camadas | Routes → services → models; schemas Pydantic; routers em `router.py` |

#### REF — Modelos de domínio

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-05 | DONE   | Modelos base | User, Position, Technique, Lesson; PK UUID; UUIDMixin (created_at, updated_at) |
| B-06 | DONE   | LessonProgress | user_id, lesson_id, completed_at; constraint única (user, lesson) |
| B-07 | DONE   | TrainingFeedback | user_id, position_id, difficulty_level, note |
| B-08 | DONE   | Mission | id, lesson_id, start_date, end_date, is_active, created_at; FK para Lesson; migration SQL |

#### REF — Health e seed

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-09 | DONE   | Health check | GET `/health` e GET `/health/db` (com conexão Postgres) |
| B-10 | DONE   | Seed de dados | Script popula 1 usuário, 2 posições, 1 técnica, 1 lição; executável via `docker compose exec api python -m app.scripts.seed` |

#### REF — Exceções e erros HTTP

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-11 | DONE   | Exceções de domínio | AppError, NotFoundError; LessonNotFoundError, TechniqueNotFoundError, UserNotFoundError, PositionNotFoundError; AlreadyCompletedError (409) |
| B-12 | DONE   | Exception handlers | Mapeamento único para HTTP (404, 409, etc.) em `main.py` |

#### REF — Lições (Lesson)

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-13 | DONE   | Listar lições | GET `/lessons` retorna lista ordenada por `order_index` |
| B-14 | DONE   | CRUD de Lesson | Schemas LessonCreate, LessonUpdate, LessonRead; service: get_by_id, create, update, delete |
| B-15 | DONE   | Rotas CRUD | GET `/lessons/{id}`, POST `/lessons`, PUT `/lessons/{id}`, DELETE `/lessons/{id}`; 404/409 quando aplicável |
| B-16 | DONE   | Validação de técnica no CRUD | Create/update de Lesson valida technique_id; TechniqueNotFoundError se não existir |

#### REF — Missão do dia

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-17 | DONE   | Entidade Mission | Separação conteúdo (Lesson) x entrega diária (Mission); período start_date/end_date; is_active |
| B-18 | DONE   | get_today_mission() | Retorna missão ativa em que hoje ∈ [start_date, end_date]; Lesson (e Technique/Position) carregados em 1 query |
| B-19 | DONE   | Fallback sem missão | Se não houver missão para hoje, usa primeira lição por order_index |
| B-20 | DONE   | Response pronta para frontend | MissionTodayResponse: mission_title, lesson_title, description, video_url, position_name, technique_name, objective, estimated_duration_seconds |
| B-21 | DONE   | GET /mission_today | Retorna payload montado no backend (sem lógica no app); 404 se não houver missão/lição |

#### REF — Conclusão e feedback

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-22 | DONE   | Registrar conclusão de lição | POST `/lesson_complete` (user_id, lesson_id); 409 se já concluída |
| B-23 | DONE   | Registrar feedback de treino | POST `/training_feedback` (user_id, position_id, etc.) |

#### REF — Métricas

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-24 | DONE   | Métricas de uso | GET `/metrics/usage`: total_completions, completions_last_7_days, unique_users_completed |

#### REF — Logging

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| B-25 | DONE   | Logs estruturados | core/logging_config (formato timestamp \| level \| logger \| message \| key=value); logs em lesson, mission, lesson_complete, training_feedback, metrics |

---

### App Flutter (bjj_app)

#### REF — Base do app

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| F-01 | DONE   | Estrutura do projeto | Pastas screens, services, models, config |
| F-02 | DONE   | Tema estilo Duolingo | Verde #58CC02, fundo claro, cards arredondados, botões em destaque (`app_theme.dart`) |
| F-03 | DONE   | Modelo Mission no app | Campos alinhados à API; fromJson/toJson; TechniqueInfo |

#### REF — Missão e API

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| F-04 | DONE   | MissionService | GET `/mission_today`; retorna MissionLoadResult (mission + fromCache) |
| F-05 | DONE   | Cache offline | SharedPreferences; em falha de rede usa última missão; exibe aviso "Modo offline" |
| F-06 | DONE   | Config de API | api_config: Android 10.0.2.2:8000, demais localhost:8000 |

#### REF — Telas e navegação

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| F-07 | DONE   | HomeScreen | Carrega missão ao iniciar; loading; card (título + técnica); botão COMEÇAR; erro com "Tentar novamente" |
| F-08 | DONE   | LessonScreen | Recebe Mission; título; placeholder de vídeo; botão CONCLUIR (volta à Home) |
| F-09 | DONE   | Navegação | Home → (COMEÇAR) → LessonScreen → (CONCLUIR) → Home |

#### REF — Progresso e uso

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| F-10 | DONE   | ProgressService | Missões concluídas, percentual, meta (ex.: 5) |
| F-11 | DONE   | Registro de uso da missão | MissionUsageStorage: abertura/conclusão (before_training/after_training); animação de sucesso ao concluir |
| F-12 | DONE   | Nome do app Android | "BJJ Treino" (android:label no AndroidManifest) |

#### REF — Testes

| ID   | Status | Item | Critérios de aceite |
|------|--------|------|---------------------|
| F-13 | DONE   | Teste de widget | App inicia com HomeScreen e título "Missão do dia"; `flutter test` |

---

## Resumo

| Área | Conteúdo |
|------|----------|
| **Roadmap** | Fase 1 (MVP) + Fase 1.5 (validação de hábito) + Fases 2–5 (product fit, B2B, profissional, escala) |
| **Backend DONE** | B-01 a B-25 — Infra, modelos, CRUD Lesson, Mission, missão do dia, exceções, health, seed, lesson_complete, training_feedback, metrics/usage, logging estruturado |
| **Flutter DONE** | F-01 a F-13 — Estrutura, tema, Mission + cache, Home/Lesson, navegação, progresso, uso da missão, testes |

---

*Para detalhes de funcionalidades implementadas, ver [FUNCIONALIDADES.md](../FUNCIONALIDADES.md).*
