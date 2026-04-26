# Funcionalidades implementadas

Documento único com todas as funcionalidades do **backend (bjj_app)** e do **app Flutter (bjj_app)** até o momento.

---

## Backend (bjj_app) — FastAPI + PostgreSQL

### Infraestrutura

- **Stack:** FastAPI, PostgreSQL, SQLAlchemy, Docker, docker-compose
- **Execução:** `docker compose up` sobe API (porta 8000) e Postgres (5432)
- **Imagem da API com código novo:** `docker compose restart api` **não** reconstrói a imagem Docker; após alterar o backend use `docker compose build api` e `docker compose up -d api` (ou `docker compose up -d --build api`).
- **Documentação:** Swagger em `/docs`
- **CORS:** Habilitado para o app Flutter (web/mobile)
- **Config:** Variáveis em `.env` (pydantic-settings)

### Modelos (SQLAlchemy)

| Modelo | Descrição |
|--------|-----------|
| **User** | Usuário (email, name, academy_id opcional); UUID como PK |
| **Academy** | Academia (name, slug, weekly_theme); 3 técnicas semanais legadas (weekly_technique_id …) ou **turmas** (`weekly_technique_kits` + `weekly_kit_items`, 1–5 técnicas por turma) com escolha por semana ISO (`user_weekly_kit_choices`) |
| **Position** | Posição do jiu-jitsu (name, slug, description) |
| **Technique** | Técnica da academia (name, slug, description, video_url, base_points) — não depende mais de Position |
| **Lesson** | Aula vinculada a uma Technique (title, slug, video_url, order_index) |
| **LessonProgress** | Conclusão de lição por usuário (user_id, lesson_id, completed_at); constraint única (user, lesson) |
| **Mission** | Missão ativa (técnica, nível, academia); `slot_index` 0–2 legado ou 0–4 com `weekly_kit_id` para turmas semanais |
| **MissionUsage** | Conclusão de missão (user_id, mission_id, usage_type: before_training \| after_training); constraint única (user, mission) |
| **TrainingFeedback** | Dificuldade em posição (user_id, position_id, difficulty_level, note) |
| **AcademyMarketplaceItem** | Anúncio da academia (`academy_id`, título, preço em centavos, moeda, `image_url` opcional, `whatsapp_phone` opcional em dígitos BR 55+DDD+número, ordem, ativo); URL `wa.me` gerada na API |

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
| GET | `/mission_today/week` | Missões semanais por nível: modo legado (3 slots) ou **turmas** (`needs_kit_choice`, `available_kits`, `selected_kit_id`, entradas `Foco 1`–`Foco N`) |
| PUT | `/users/me/weekly-kit-choice` | Aluno escolhe o kit da semana ISO (`kit_id`; `reference_date` opcional) |
| GET/POST | `/academies/{id}/weekly-kits` | Lista / cria **turmas** (1–5 técnicas; rótulo = nome da turma) |
| PATCH/DELETE | `/academies/{id}/weekly-kits/{kit_id}` | Atualiza ou remove turma |
| POST | `/academies/{id}/reset_weekly_turmas_week` | Reinicia semana ISO atual (UTC): escolhas de turma + progresso nas missões de turma na janela; pontos preservados via `points_adjustment` |
| GET/POST | `/academies/{id}/weekly_kits` | Alias legado (mesmo contrato que `weekly-kits`; omitido do OpenAPI) |
| PATCH/DELETE | `/academies/{id}/weekly_kits/{kit_id}` | Alias legado (idem) |
| GET | `/mission_usages/history` | Histórico de missões concluídas (user_id, limit) |
| GET | `/lesson_complete/status` | Verifica se lição já foi concluída (user_id, lesson_id) |
| POST | `/mission_complete` | Conclusão por missão (user_id, mission_id, usage_type: before_training \| after_training); 409 se já concluiu |
| GET | `/metrics/usage` | Métricas de uso (totais, últimos 7 dias, % antes do treino) |
| POST | `/lesson_complete` | Registrar conclusão de lição (user_id, lesson_id); evita duplicata (409) |
| POST | `/training_feedback` | Registrar dificuldade em posição (user_id, position_id, observation opcional) |
| GET | `/me/marketplace_items` | Lista anúncios ativos da academia do utilizador (vazia sem `academy_id`) |
| GET/POST | `/marketplace_items` | Lista ou cria anúncios; body com `whatsapp_ddd` + `whatsapp_number` opcionais (ou omitir ambos); resposta inclui `whatsapp_url` calculada quando há telefone |
| PUT/DELETE | `/marketplace_items/{id}` | Atualizar ou remover anúncio (mesmo isolamento por academia) |

#### Seção Academia (CRUD e relatórios)

Ver documentação detalhada em **[docs/ACADEMIAS.md](docs/ACADEMIAS.md)**.

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/academies` | Lista academias |
| POST | `/academies` | Criar academia (body: name, slug opcional) |
| GET | `/academies/{id}` | Detalhe de uma academia |
| PATCH | `/academies/{id}` | Atualizar academia (body: name?, slug?, weekly_theme?) |
| DELETE | `/academies/{id}` | Excluir academia |
| GET | `/academies/{id}/ranking` | Ranking interno (`period_days` ou `start_date`+`end_date`, `limit`) |
| GET | `/academies/{id}/difficulties` | Posições mais reportadas como difíceis |
| GET | `/academies/{id}/report/weekly` | Conclusões no período (`year`/`week` ISO ou `start_date`+`end_date`) |
| GET | `/academies/{id}/report/weekly/csv` | Export CSV (mesmos parâmetros) |
| POST | `/academies/{id}/students/bulk-import` | Importa alunos em lote via Excel `.xlsx` (colunas: E-MAIL, NOME, SENHA, GRADUAÇÃO). E-mails existentes são pulados; resposta traz resumo + erros por linha |
| GET | `/missions` | Lista missões (academy_id, limit opcionais) |
| GET | `/missions/{id}` | Detalhe de uma missão |
| POST | `/missions` | Criar missão (lesson_id, start_date, end_date, level, theme?, academy_id?) |
| PATCH | `/missions/{id}` | Atualizar missão (campos parciais) |
| DELETE | `/missions/{id}` | Excluir missão |
| GET | `/missions/panel` | Painel web HTML para criar missão em 10s |

- Validação de body (Pydantic); 404 para recurso não encontrado; 409 para conclusão duplicada
- Exceções de domínio em `app/core/exceptions`; mapeamento para HTTP via exception handlers

### Pontuação de recompensas (10–50)

- **Vídeo de treinamento (diário):** `points_per_day` entre **10** e **50** (pontos por visualização válida no dia).
- **Missão:** `multiplier` entre **10** e **50**; ao concluir (`POST /mission_complete`), o aluno recebe **pontos = `mission.multiplier`** (valor fixo da missão, não depende da faixa do usuário).
- **Academia (slots semanais):** `weekly_multiplier_1`, `weekly_multiplier_2`, `weekly_multiplier_3` entre **10** e **50** (usados no cálculo de pontos de execuções confirmadas ligadas ao slot).
- **Missão do dia / semana (API):** o campo `multiplier` na resposta reflete o da missão (10–50); em fallback sem missão real (só técnica), usa **10** como valor exibido.
- Migração **`047_clamp_reward_points_10_50.sql`:** ajusta dados antigos para a faixa e define default **10** nas colunas afetadas.

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
     - **Troféus:** linha "Troféus" (como "Técnicas") abre **`TrophyListScreen`** → módulo **`features/trophies`** (Riverpod + Hive): busca, criar/editar em formulário completo, excluir (soft delete na API). No formulário: **nível para desbloquear** (`reward_level` do aluno; 0 = sem exigência), faixa mínima opcional, tipo (medalha/troféu) e duração mínima para troféu especial. Ao editar período/técnica/meta, o app pede confirmação (impacto nas conquistas). Ver [`viewer/lib/features/trophies/README.md`](viewer/lib/features/trophies/README.md).
     - **Missões semanais:** 3 dropdowns para selecionar técnica (Missão 1, Missão 2, Missão 3). Se só Missão 1 estiver preenchida, aparece missão apenas no slot 1.
     - **Tema da semana:** campo de texto + **Salvar tema** (PATCH /academies/{id}).
     - **Ranking (últimos 30 dias):** lista legível (posição, nome, conclusões).
     - **Dificuldades reportadas:** posições mais marcadas como difíceis (nome, quantidade de reportes).
     - **Período dos relatórios:** data inicial e final (calendário); ranking, conclusões e logins usam o mesmo intervalo.
     - **Conclusões / ranking / logins:** respeitam esse período (API: até 366 dias).
   - Estado vazio: mensagem quando não há academias cadastradas.

### CRUD Técnicas (módulo admin — referência para outros CRUDs)

Implementação de referência em **`viewer/lib/features/techniques/`** (Riverpod + Clean Architecture + Hive):

- Lista por academia com sync na API, cache Hive, aviso se a lista puder estar desatualizada (falha de rede).
- Após **criar / editar / excluir**: invalidação do cache HTTP do `ApiService`, limpeza do Hive dessa lista e novo sync; overlay de loading durante mutações.
- **Criação rápida** (FAB): bottom sheet com `createOptimistic` no notifier.
- **Formulário completo** (`technique_form_screen.dart`): após salvar, `Navigator.pop` devolve o modelo gravado; a lista funde o item e reconcilia com o servidor (`syncAfterFormClose(saved:)`).
- Busca com debounce, paginação client-side, pull-to-refresh.

Documentação detalhada para replicar o padrão em lições, missões, etc.: **[docs/CRUD_PADRAO_FLUTTER.md](docs/CRUD_PADRAO_FLUTTER.md)**.

### Outras telas do app

- **Loja da academia (marketplace):** na aba **Campo de treinamento** (`StudentHomeScreen`), **último bloco** do scroll (após **Confirmações e solicitações**): atalho **Loja da academia** → `MarketplaceScreen` (preço; botão WhatsApp só se o anúncio tiver telefone). Visível para **qualquer utilizador logado**; sem `academy_id` a API pode devolver lista vazia. Cadastro com **DDD e número opcionais**; mensagem do `wa.me` é fixa no backend. **Painel Academia** / **Admin**: `MarketplaceListScreen` / `MarketplaceFormScreen`; admin indica `academy_id` ao criar. (`HomePage` mantém o mesmo atalho se for reutilizada noutro fluxo.)
- **Biblioteca de lições** (aba Lições): lista GET /lessons; toque abre a lição como LessonScreen (e envia POST /lesson_complete ao concluir).
- **Galeria de troféus e medalhas:** lista em cards com filtros (tier, tipo), switch "Galeria visível para outros" (PATCH /auth/me), "Indicar adversário". Itens podem aparecer **trancados** até o aluno atingir o **nível mínimo** e a **faixa** definidos no troféu. **Regra:** só é permitido **indicar o mesmo colega 1 vez por dia** (por usuário → adversário, no fuso do app). Ícone da AppBar **"Ver como estante"** abre a visão gamificada (prateleiras, glow ouro, modal de detalhes). Ver [docs/TROPHY_SHELF.md](docs/TROPHY_SHELF.md).
- **Importação em lote de alunos (Excel):** na lista **Usuários** existe a ação **“Importar alunos (Excel)”** (gera upload `.xlsx` para a academia e recarrega a lista).
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
| **Backend** | API REST, modelos, missão do dia, missões semanais **legado (3 slots) ou turmas** (1–5 técnicas, escolha por semana ISO UTC), `POST …/reset_weekly_turmas_week`, conclusão de lição/missão (com usage_type), lesson_complete/status, feedback de treino, positions, mission_usages/history, metrics/usage; área professor: academies (CRUD turmas `weekly-kits` + alias, tema, ranking, difficulties, report/weekly), missions CRUD; seed com academia e missões |
| **App** | Tela inicial com missões semanais (modo legado 3 slots ou **escolha de turma**), lição (botão concluído desabilitado quando já feito), diálogo antes/depois do treino ao concluir missão, biblioteca de lições, **galeria de troféus/medalhas** (lista + estante gamificada), progresso com histórico (data sem horário), reportar dificuldade, métricas; **Área do professor:** missões (CRUD) e academias (missões legadas ocultas com turmas ativas, **painel de turmas**, tema, período comum para ranking/conclusões/logins, dificuldades) |
