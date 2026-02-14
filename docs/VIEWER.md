# Viewer — App Flutter (JJB)

App Flutter para **alunos** e **professores** de jiu-jitsu. Interface web responsiva e tema estilo Duolingo.

---

## Como rodar

1. API rodando em `http://localhost:8000`.
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
- **Dispositivo físico:** use o IP da máquina (ex.: `http://192.168.1.10:8000`)

---

## Navegação

| Menu      | Descrição                                              |
|-----------|--------------------------------------------------------|
| **Início** | Tela inicial do aluno (3 missões semanais) ou painel admin |
| **Administração** | CRUD de Academias, Usuários, Lições, Técnicas, Posições, Missões |

---

## Telas do aluno

### StudentHomeScreen

- Carrega `GET /mission_today/week` (3 missões semanais).
- Exibe 3 cards: **Missão 1**, **Missão 2**, **Missão 3**.
- Cada card mostra a técnica ou fica vazio se não houver missão no slot.
- Toque em um card → navega para `LessonViewScreen` com a missão selecionada.

### LessonViewScreen

- Exibe título, descrição, vídeo (ou placeholder) da lição/missão.
- **Botão "Concluir"**:
  - Se já concluído (`alreadyCompleted` ou `GET /lesson_complete/status`): exibe "Lição concluída" ou "Missão concluída" e desabilita.
  - Se missão: ao concluir, exibe diálogo **"Quando você visualizou?"** com:
    - **Antes do treino**
    - **Depois do treino**
  - Se lição (biblioteca): envia `POST /lesson_complete` diretamente.
- Em 409 (já concluído): troca botão para conclusão e desabilita.

### LibraryScreen

- Lista lições via `GET /lessons`.
- Toque → abre `LessonViewScreen` (modo biblioteca; concluir = `POST /lesson_complete`).

### ProgressScreen (Meu progresso)

- Seção "Últimas missões concluídas" com `GET /mission_usages/history`.
- Data exibida **sem horário** (ex.: 12/02/2025).

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

### MissionListScreen / MissionFormScreen

- CRUD de missões (lição/técnica, datas, nível, tema, academia).
- Botão + para criar; toque para editar; menu ⋮ para excluir.

### Outras telas admin

- `AcademiesScreen`, `UserListScreen`, `LessonListScreen`, `TechniqueListScreen`, `PositionListScreen`: listas + formulários CRUD.

---

## Estrutura do código

```
viewer/lib/
├── main.dart                 # App e shell com drawer
├── config.dart               # URL base da API
├── app_theme.dart            # Tema verde #58CC02
├── models/                   # Mission, MissionToday, MissionWeek, Academy, User, Lesson, etc.
├── services/
│   ├── api_service.dart      # Cliente HTTP (getMissionToday, getMissionWeek, postMissionComplete, etc.)
│   ├── academy_service.dart  # Operações de academia
│   └── professor_service.dart
└── screens/
    ├── home_screen.dart
    ├── student/              # Telas do aluno
    │   ├── student_home_screen.dart
    │   ├── lesson_view_screen.dart
    │   ├── lesson_view_data.dart
    │   ├── library_screen.dart
    │   ├── progress_screen.dart
    │   └── report_difficulty_screen.dart
    ├── admin/                # Telas de administração
    │   ├── academy_detail_screen.dart
    │   ├── mission_list_screen.dart
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
