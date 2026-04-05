# FlowRoll — App Flutter (viewer)

App Flutter para **alunos** e **professores** de jiu-jitsu. Interface web responsiva e tema estilo Duolingo.

---

## Como rodar

1. API Docker no host: `http://localhost:8001` (uvicorn só no PC: `http://localhost:8000` e `?api_base=...` se precisar).
2. Na pasta `viewer`:

```bash
cd viewer
flutter pub get
flutter run
```

**Docker:** o serviço `viewer` é buildado com Flutter web e servido via nginx:

```bash
docker compose up -d --build api viewer
```

Acesse: **http://localhost:8080**

---

## URL da API

- **Web:** `kApiBaseUrl` em `lib/config.dart` ou `--dart-define=API_BASE_URL=http://localhost:8000`
- **Emulador Android:** use `http://10.0.2.2:8000`
- **Dispositivo físico:** use o IP da máquina em `viewer/lib/config_stub.dart` (ex.: `http://192.168.0.14:8000`). Para todas as configurações (Android, cleartext, firewall, APK), veja [ANDROID_APK_LOCAL.md](ANDROID_APK_LOCAL.md).

### Login e mensagens de erro

- **`login_screen.dart`**: layout tipo landing com fundo roxo-carvão, cartão centrado, campos preenchidos em tom escuro e botão dourado; a marca é **`assets/branding/flowroll_wordmark.png`** (texto branco + cinto no “O”, fundo transparente sobre o cartão). O **favicon** e os **ícones PWA** (`web/favicon.png`, `web/icons/Icon-*.png`) são gerados a partir da mesma wordmark com `python scripts/generate_pwa_icons_from_wordmark.py` (fundo `#262433` para contraste na barra do browser).
- Se o Chrome mostra **401** em `POST /auth/login`, a API está a responder: o problema é normalmente **e-mail ou senha incorretos**, não “API desligada”.
- **Ambiente Docker com seed** (conforme scripts de arranque do projeto): credenciais típicas `admin@jjb.com` / `saas`.
- Após **restaurar um backup** (`POST /admin/backup/restore`), os utilizadores e hashes vêm do ficheiro SQL: use as credenciais **desse** banco, não as do seed.
- O viewer (`userFacingMessage` em `lib/utils/error_message.dart`) distingue falhas de rede reais de `ApiException`; em 401 mostra o detalhe da API e a dica acima.

### Sincronização de academia e vídeos do dia

- **`ApiService.getAcademyFresh`**: se `GET /academies/{id}` devolver **403**, o cliente chama `AuthService().refreshMe()` e repete o pedido com o `academy_id` atual de `/auth/me` (corrige utilizador em cache desatualizado após mudança de academia no servidor).
- **`getTrainingVideosToday`**: pedidos em voo ao mesmo endpoint são **coalescidos** (uma única requisição HTTP partilhada), para aliviar rajadas paralelas na home e reduzir erros tipo `ERR_INSUFFICIENT_RESOURCES` no Chrome.
- **`StudentHomeScreen` / `HomePage`**: após o `Future.wait` inicial, o estado local do utilizador é **realinhado** com `AuthService().currentUser`; o filtro do vídeo diário usa o `academy_id` lido **depois** de `getTrainingVideosToday()`, para coincidir com o perfil já sincronizado.

---

## Navegação

| Menu      | Descrição                                                                 |
|-----------|---------------------------------------------------------------------------|
| **Início** | Tela inicial do aluno (3 missões semanais) ou painel admin               |
| **Administração** | CRUD de Academias, Usuários, vídeos, relatórios, auditoria, **backup SQL** da base |

### MainShell (`lib/main.dart`)

- **Aluno** (`role == aluno`): barra inferior só com a aba **Campo de treinamento** (sem **Academia**). **Professor**, **gerente** e **supervisor** mantêm **Campo de treinamento** + **Academia**. Apenas **administrador** (admin global) tem também a aba **Admin** (CRUD global, relatórios completos, auditoria, backup).
- Com **Atuar como**, as abas seguem o **papel efetivo** (`GET /auth/me` com `X-Impersonate-User`): ao simular um **gerente** ou **aluno**, o admin real **deixa de ver** a aba **Admin** (só volta ao sair da simulação ou ao atuar como outro administrador). O botão **Atuar como** na AppBar continua visível para quem fez login como administrador real (`isRealUserAdmin`), graças a `_currentUser` preenchido com `getAuthMeAsRealUser` no arranque e em `setImpersonating`. **Supervisor** em simulação mantém **Academia** (via `isRealUserSupervisor` no `RoleGuard` do painel), mas **não** a aba **Admin**.
- A secção **Admin** e os ecrãs aí ligados exigem papel efetivo **administrador** (sem exceção “admin real em simulação”). **Backup** e **auditoria** idem.
- Aba **Campo de treinamento** pode mostrar **badge** de confirmações pendentes (`onPendingConfirmationsCountChanged`). Quando existir aba **Academia**, o valor do badge mantém-se ao mudar de aba até a home recarregar e zerar o contador.
- Ao trocar de utilizador efetivo (ex.: impersonação), o badge é reposto a zero até a home voltar a carregar.

---

## Telas do aluno

### StudentHomeScreen

- **Tema claro/escuro:** o fundo atrás do scroll (`_FantasyBackground` → `FantasyTheme.missionHomeBackgroundDecoration`) e os cartões da home fantasia (`FantasyTheme.cardBoxDecoration`, `textPrimaryOf`, `insetSurfaceOf`, etc.) usam o `Brightness` atual: em **claro**, fundo alinhado ao scaffold e cartões ao `ColorScheme.surface`; em **escuro**, mantém o gradiente espacial e cartões roxos como antes.
- **`HeaderWidget`**: saudação *Olá, …* no topo; **sob o brasão** só o texto **Faixa** + graduação (ex. Faixa Preta), sem repetir o nome nessa linha.
- Abaixo do cabeçalho, cartão **`StreakWidget(streakDays: …, onOpenPointsRules: …)`** com `login_streak_days` de **`GET /auth/me`**: sequência (flame + dias) e, **no mesmo cartão** à direita, **`LoginBonusRing`** (`login_bonus_ring.dart`) — progresso até ao próximo múltiplo de 7 dias, centro **+50 PTS** (`gamification_constants.dart`); toque no anel abre **Como funcionam os pontos** (`showPointsRulesSheet` em `points_rules_sheet.dart`).
- Carrega `GET /mission_today/week` (3 missões semanais).
- **`WeeklyMissionPath`** (`lib/widgets/gamification/weekly_mission_path.dart`): no scroll principal, com título **Missões da semana** acima do cartão; ✓ / play / cadeado; **três filas** partilham a mesma grelha `Row`: colunas com largura **`kWeeklyPathNodeColumnWidth`** (48 + padding do nó) e **`Expanded`** entre colunas, para o play, o **nome da técnica** (uma linha, centrado sob o nó, reticências; **`Tooltip`** com o nome completo) e o estado (**Treinar** / Feito) ficarem alinhados na vertical; haptic, alvos tocáveis **48×48** dentro da coluna, segmentos com contraste reforçado, **pulso** ao concluir missão (`celebrateMissionId`). Toque no nó ou no estado → `LessonViewScreen`.
- **Removidos** da home: cartão “Você já concluiu X de Y missões” + barra linear; acordeão **Missões da semana** com os três cards “Começar”.
- **Centro de treinamento**: acordeão só aparece quando não há `missionWeek` (mensagem para configurar academia ou “nenhuma missão”). Com missões carregadas o acordeão **não** é mostrado.
- **`TrophiesHomeSection`** (`lib/widgets/trophies_home_section.dart`): título **Troféus** + cartão com o mesmo `FantasyTheme.cardBoxDecoration` que **Parceiros** (gradiente no escuro, superfície clara no tema claro), linhas para **Galeria de troféus** e, com academia, **Galeria dos colegas**. Respeita `academy.showTrophies` (`_showTrophies`). Fica no scroll **após** o Centro de treinamento (se visível) e **antes** de Parceiros.
- O acordeão **Confirmações e solicitações** fica no **fim do scroll**, depois de horários e apoiantes globais.
- **Confirmações pendentes** (`GET` contador via `ApiService.getPendingConfirmationsCount`):
  - **Banner** sob o cabeçalho quando `count > 0`: texto + **Abrir** → `PendingConfirmationsScreen`; **X** oculta o banner até o contador mudar (nova resposta da API).
  - **Bottom sheet** uma vez por montagem da tela (após o fluxo de parceiro em destaque, se houver): resume o número de pendentes, **Ir confirmar** ou **Depois**.
  - Parâmetro opcional `onPendingConfirmationsCountChanged` para o `MainShell` atualizar o badge da aba **Campo de treinamento**.

### LessonViewScreen

- Exibe título, descrição, vídeo (ou placeholder) da lição/missão.
- **Botão "Concluir"**:
  - Se já concluído (`alreadyCompleted` ou `GET /lesson_complete/status`): exibe "Lição concluída" ou "Missão concluída" e desabilita.
  - Se missão: ao concluir, exibe diálogo **"Quando você visualizou?"** com:
    - **Antes do treino**
    - **Depois do treino**
  - Se lição (biblioteca): envia `POST /lesson_complete` diretamente.
- Em 409 (já concluído): troca botão para conclusão e desabilita.
- Após **`POST /mission_complete`** ou **`POST /lesson_complete`** com sucesso (fluxo sem oponente / sem execução pendente): abre **`RewardScreen`** com o campo **`points_awarded`** da resposta JSON; a barra de nível usa **`GET /users/{id}/points`** depois do POST. Se a resposta não trouxer `points_awarded` (API antiga), o app usa estimativa (`clampRewardPoints(multiplicador)` na missão; lição = `minRewardPoints`) e mostra nota no diálogo.

### Widgets de gamificação (`lib/widgets/gamification/`)

- **`animated_button.dart`**: micro-escala ao premir (respeita *reduce motion*).
- **`xp_bar.dart`**: barra de progresso reutilizável.
- **`reward_screen.dart`**: diálogo pós-conclusão.
- **`streak_widget.dart`**: dias seguidos com login; `streakDays == null` não renderiza; `0` usa ícone outline e texto para reforçar o hábito; `n >= 1` mostra contagem e “dia(s) seguido(s)”.
- **`weekly_mission_path.dart`**: caminho das 3 missões; grelha alinhada (`kWeeklyPathNodeColumnWidth` + `Expanded` entre colunas nas três filas); haptic; animação de conclusão; `kWeeklyPathMinTapSize` (48) para área mínima de toque do nó.
- **`gamification.dart`**: export barrel.

### LibraryScreen

- Lista lições via `GET /lessons`.
- Toque → abre `LessonViewScreen` (modo biblioteca; concluir = `POST /lesson_complete`).

### ProgressScreen (Meu progresso)

- Seção "Últimas missões concluídas" com `GET /mission_usages/history`.
- Data exibida **sem horário** (ex.: 12/02/2025).

### Galeria de troféus e medalhas

- **TrophyGalleryScreen:** lista em cards com filtros (tier, tipo medalha/troféu), switch "Galeria visível para outros", "Indicar adversário". Consome `GET /trophies/user/{user_id}`.
- **Estante (TrophyShelfPage):** na galeria, ícone da AppBar **"Ver como estante"** abre a visão gamificada: prateleiras, troféus com estado bloqueado/ouro (glow), toque abre modal de detalhes. Mesma API; 403 quando galeria privada. Detalhes em [TROPHY_SHELF.md](TROPHY_SHELF.md).

### ReportDifficultyScreen

- `GET /positions` para escolher posição.
- Campo de observação opcional.
- `POST /training_feedback`.

---

## Telas do professor

Acesso via **Perfil → Área do professor** ou **Administração**.

### AcademyDetailScreen

- **Missões semanais:** 3 dropdowns (Missão 1, Missão 2, Missão 3) para selecionar técnica.
- **Tema da semana:** campo de texto + Salvar tema.
- **Ranking:** últimos 30 dias.
- **Dificuldades reportadas:** posições mais marcadas.
- **Relatório semanal:** período, total de conclusões, ativos, ranking.
- **Logins na semana:** seção separada com total de utilizadores (staff e alunos) que logaram ao menos 1 dia e lista por utilizador com quantidade de dias.
- **Execuções focadas em troféu/medalha/posição:** usa `/metrics/usage/by_academy` para mostrar premeditadas vs naturais.

### ExecutionReportsScreen (Relatórios de execuções)

- Acesso via **Administração → Relatórios de execuções**.
- Mostra visão **global** e por **academia** de execuções premeditadas vs naturais:
  - Global: chama `GET /metrics/usage`.
  - Por academia: chama `GET /metrics/usage/by_academy`.
- Divide entre:
  - **Premeditadas**: foco em troféu/medalha/posição.
  - **Naturais**: aconteceram sem foco explícito.

### EngagementReportsScreen (Relatórios de engajamento)

- Acesso via **Administração → Relatórios de engajamento**.
- Permite escolher uma **data de referência** e, opcionalmente, **filtrar por academia**.
- Usa:
  - `GET /reports/engagement` — resumo de engajamento **semanal** e **mensal**.
  - `GET /reports/active_students` — lista de alunos ativos na janela de 7 dias (apenas backend; CSV via `/reports/active_students/csv`).
  - `GET /reports/weekly_panel_logins` — logins semanais de staff e alunos (global ou por academia).
- Definição usada na tela:
  - **Aluno ativo** = fez pelo menos **1 login** no app nos **últimos 7 dias** em relação à data de referência.
- Componentes principais:
  - **Visão global** (todas as academias): cards com:
    - Semana: `% de alunos ativos`, `ativos / total`, intervalo de datas.
    - Mês: `% de alunos ativos`, `ativos / total`, intervalo de datas.
    - Logins na semana (staff e alunos): `logaram ao menos 1 dia / elegíveis` e amostra da lista.
  - **Filtro por academia**: dropdown com academias; ao selecionar, aparece card “Visão da academia X” com os mesmos dados.

### MissionListScreen / MissionFormScreen

- CRUD de missões (lição/técnica, datas, nível, tema, academia).
- Botão + para criar; toque para editar; menu ⋮ para excluir.

### DatabaseBackupScreen (Backup do banco de dados)

- Acesso via **Administração → Backup do banco de dados**.
- **Exportar:** botão principal — `GET /admin/backup/archive` → arquivo **.zip** (`database.sql` + pasta `media/`) via `file_saver`, timeout longo (~10 min), **usuário real** (sem `X-Impersonate-User`).
- **Exportar (avançado):** `GET /admin/backup/database` → só `.sql` (sem mídia).
- **Restaurar:** diálogo exige digitar `RESTAURAR`; depois `FilePicker` (`.zip`). `POST /admin/backup/restore` em multipart; timeout do cliente ~2 h 15 min (alinha com `psql` longo no servidor). O pedido inteiro (upload + espera da resposta) está dentro de um único `Future.timeout`. Na **web** usa-se `withData: true` (arquivo em memória); em **IO** usa-se `path` quando disponível (`backup_multipart_io.dart` / `backup_multipart_web.dart`). Após sucesso, `ApiService.invalidateCache()` limpa cache HTTP. A API valida `SELECT 1` após o restore para evitar ligações mortas ao Postgres.

### Outras telas admin

- `AcademyListScreen`, `UserListScreen`, `TrainingVideoListScreen`, listas de lições/técnicas/posições/missões: CRUD conforme o ecrã.
- **`TrophyFormScreen`** (`admin/trophy_form_screen.dart`): novo registo abre com tipo **Medalha (ordinária)** por defeito (períodos curtos sem validação de 30 dias no servidor). **Troféu (especial)** continua a exigir duração mínima configurável (cliente + API).

---

## Estrutura do código

```
viewer/lib/
├── main.dart                 # App e shell com drawer
├── config.dart               # URL base da API
├── app_theme.dart            # Tema verde #58CC02
├── features/
│   └── trophy_shelf/        # Estante gamificada (ver TROPHY_SHELF.md)
│       ├── domain/shelf_trophy.dart
│       ├── presentation/trophy_shelf_page.dart + widgets/
│       └── utils/shelf_layout_config.dart
├── models/                   # Mission, MissionToday, MissionWeek, Academy, User, Lesson, Trophy, etc.
├── services/
│   ├── api_service.dart      # Cliente HTTP (getMissionToday, getTrophiesForUser, etc.)
│   ├── academy_service.dart  # Operações de academia
│   └── professor_service.dart
└── screens/
    ├── home_screen.dart
    ├── student/              # Telas do aluno
    │   ├── student_home_screen.dart
    │   ├── lesson_view_screen.dart
    │   ├── library_screen.dart
    │   ├── progress_screen.dart
    │   ├── trophy_gallery_screen.dart   # Galeria lista + atalho para estante
    │   └── report_difficulty_screen.dart
    ├── admin/                # Telas de administração
    │   ├── academy_detail_screen.dart
    │   ├── database_backup_screen.dart  # ZIP/SQL + restaurar (admin)
    │   ├── user_list_screen.dart       # Ação "Ver galeria" por usuário
    │   └── ...
    └── academy/              # Painel de academia
```

---

## Modelos principais

| Modelo            | Uso                                             |
|-------------------|--------------------------------------------------|
| `MissionToday`    | Missão do dia (título, vídeo, técnica)           |
| `MissionWeek`     | Resposta de `GET /mission_today/week`            |
| `MissionWeekSlot` | Um slot (period_label, mission)                  |
| `LessonViewData`  | Dados para LessonViewScreen (incl. alreadyCompleted) |
| `Academy`         | Academia (nome, 3 técnicas semanais)             |

---

## API Service

Principais métodos em `ApiService`:

| Método                         | Endpoint                     |
|--------------------------------|------------------------------|
| `getMissionToday`              | GET /mission_today           |
| `getMissionWeek`               | GET /mission_today/week      |
| `getLessonCompleteStatus`      | GET /lesson_complete/status  |
| `postLessonComplete`           | POST /lesson_complete        |
| `postMissionComplete(usageType)` | POST /mission_complete    |
| `getMissionHistory`            | GET /mission_usages/history  |
| `getLessons`                   | GET /lessons                 |
| `getPositions`                 | GET /positions               |
| `postTrainingFeedback`         | POST /training_feedback      |
| `getUsageMetrics`              | GET /metrics/usage           |
| `downloadBackupArchive`        | GET /admin/backup/archive      |
| `downloadDatabaseBackup`       | GET /admin/backup/database   |
| `restoreBackupZip`             | POST /admin/backup/restore     |
| `getTrophiesForUser(userId)`   | GET /trophies/user/{user_id} |
| `patchMeGalleryVisible(bool)`  | PATCH /auth/me (galeria visível) |
