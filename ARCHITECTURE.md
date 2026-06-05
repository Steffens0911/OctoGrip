# ARCHITECTURE — Octogrip (AppBaby)

> Auditoria gerada em 2026-06-04  
> Stack: FastAPI · PostgreSQL · Redis · Celery · Flutter 3

---

## Índice

1. [Visão Geral](#1-visão-geral)
2. [Fluxograma da Aplicação](#2-fluxograma-da-aplicação)
3. [Diagrama de Componentes](#3-diagrama-de-componentes)
4. [Mapa de Dependências](#4-mapa-de-dependências)
5. [Modelos de Dados](#5-modelos-de-dados)
6. [Padrões Arquiteturais](#6-padrões-arquiteturais)
7. [Fluxos Críticos](#7-fluxos-críticos)
8. [Débitos Técnicos e Melhorias Priorizadas](#8-débitos-técnicos-e-melhorias-priorizadas)

---

## 1. Visão Geral

O **Octogrip** é uma plataforma SaaS de gamificação para academias de jiu-jitsu. Alunos ganham pontos e troféus ao executar e confirmar técnicas; professores controlam presença; administradores gerenciam todo o conteúdo.

### Runtime

```
Internet
  │
  ▼
[Flutter Web / Mobile App]
  │  HTTPS / WebSocket
  ▼
[FastAPI :8001]──────────────────────────────────┐
  │          │                                   │
  │   [PostgreSQL 16]          [Redis 7]         │
  │          │                    │              │
  └──────────┴───────────────[Celery Worker]     │
                                  │              │
                         [Celery Beat]           │
                                  │              │
                        [Firebase FCM]◄──────────┘
```

### Tecnologias por camada

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Frontend | Flutter / Dart | 3.x |
| State management | Riverpod | 2.5 |
| HTTP API | FastAPI | 0.115 |
| ORM | SQLAlchemy (async) | 2.0 |
| Banco | PostgreSQL | 16 |
| Cache / Broker | Redis | 7 |
| Workers | Celery | 5.x |
| Reconhecimento facial | DeepFace + TensorFlow | - |
| Push | Firebase Cloud Messaging | - |
| Containers | Docker Compose | - |

---

## 2. Fluxograma da Aplicação

### 2.1 Fluxo Principal — Aluno

```
┌──────────────────────────────────────────────────────────────────┐
│                        JORNADA DO ALUNO                          │
└──────────────────────────────────────────────────────────────────┘

   Login ──► Daily Check-in ──► Streak bonus aplicado
     │
     ▼
   StudentHomeScreen
     ├── Missão do dia (GET /mission_today)
     │     └── Técnica/Lição da semana (slot 1-3 × multiplier)
     ├── Barra XP + Nível (reward_level)
     ├── Troféus recentes
     └── Vídeos de treinamento voluntários

     │  Aluno vai treinar
     ▼
   LessonViewScreen
     └── Assiste vídeo, estuda técnica

     │  No tatame
     ▼
   OpponentPickerSheet ──► POST /executions
     │                       status = pending_confirmation
     ▼
   (Adversário recebe push)
     │
   PendingConfirmationsScreen ──► POST /executions/{id}/confirm
     │                              OU reject
     ▼
   Pontos calculados:
     points = base × graduation_factor(adversário) × slot_multiplier
     reward_level é recalculado
     Notificação "execução confirmada" enviada ao aluno

     │  Se não confirmado em 4 dias
     ▼
   Celery: escalate_pending_executions_to_professor
     └── Professor revisa via ProfessorReviewScreen

     │  Ao atingir meta do troféu
     ▼
   UserTrophyEarned criado (gold / silver / bronze)
   Push de troféu enviado
   TrophyGalleryScreen atualizada
```

### 2.2 Fluxo — Presença (QR)

```
Professor                           Aluno
─────────────────────────────────────────────────────
POST /attendance/sessions           GET QR code
  → AttendanceSession criada           │
  → expires_at = now + 2h              ▼
                                    AttendanceScanScreen
                                    Escaneia QR
                                       │
                                       ▼
                                    POST /attendance/sessions/{id}/record
                                      → AttendanceRecord salvo
                                      → method = qr

POST /attendance/sessions/{id}/close
  → Relatório disponível
```

### 2.3 Fluxo — Reconhecimento Facial

```
Aluno                              Backend
──────────────────────────────────────────────────────────
Upload selfie                      
POST /face-recognition/upload  ──► Salva imagem S3 / local
                                   │
                                   ▼ (Celery task)
                               DeepFace.represent()
                               FaceNet512 embedding
                               Salva StudentFaceEmbedding
                                   │
                               Professor: POST imagem câmera
                                   │
                                   ▼
                               Compara embedding × academia
                               Resultado: matches[]
                                   │
                                   ▼ (FCM)
                               Push para professor
                               AttendanceRecord bulk insert
```

### 2.4 Fluxo — Notificações Push

```
Evento                          Backend                     Dispositivo
──────────────────────────────────────────────────────────────────────
Execução confirmada ──► execution_notification_service ──► FCM ──► Push
Troféu conquistado  ──► trophy_notification_service    ──► FCM ──► Push
Streak em risco     ──► Celery 23:00 UTC               ──► FCM ──► Push
Alunos em risco     ──► Celery Seg 12:00 UTC            ──► FCM ──► Push (prof)
Prof tem pendentes  ──► Celery 08:00 UTC               ──► FCM ──► Push
```

---

## 3. Diagrama de Componentes

### 3.1 Backend

```
app/
├── main.py                  ← FastAPI app, middlewares, routers
│
├── core/
│   ├── auth_deps.py         ← JWT decode, get_current_user
│   ├── role_deps.py         ← require_role(aluno|professor|admin)
│   ├── security.py          ← JWT create/verify, pwd hash
│   ├── exceptions.py        ← AppError, NotFoundError, ForbiddenError
│   ├── cache.py             ← InMemoryCache(TTL)
│   ├── rate_limit.py        ← slowapi limiter
│   ├── leveling.py          ← calculate_level_from_points()
│   ├── graduation.py        ← graduation_factor(faixa)
│   ├── app_time.py          ← now_brasilia(), today_brasilia()
│   └── points_limits.py     ← MIN=10, MAX=50
│
├── models/                  ← SQLAlchemy ORM (32 modelos)
│   ├── [Usuário]            user.py, user_login_day.py, user_device_token.py
│   ├── [Academia]           academy.py, academy_photo.py, marketplace_item.py
│   ├── [Conteúdo]           technique.py, lesson.py, training_video.py
│   ├── [Gamificação]        mission.py, mission_usage.py, trophy.py,
│   │                        technique_execution.py, collective_goal.py
│   ├── [Presença]           attendance_session.py, attendance_record.py
│   ├── [Social]             professor.py, partner.py, global_partner.py
│   └── [Sistema]            audit_log.py, notification.py, face_recognition_job.py,
│                            student_face_embedding.py, enrollment_invite.py,
│                            manual_trophy.py, weekly_technique_kit.py
│
├── schemas/                 ← Pydantic v2 (34 schemas)
│   └── [espelham models]    validação de entrada + serialização de saída
│
├── routes/                  ← FastAPI routers (36 arquivos, 150+ endpoints)
│   ├── auth.py
│   ├── users.py / students.py / admin.py
│   ├── academies.py
│   ├── techniques.py / lessons.py
│   ├── missions.py / mission.py / mission_complete.py
│   ├── executions.py
│   ├── trophies.py / manual_trophies.py
│   ├── attendance.py / face_recognition.py
│   ├── training_videos.py / me_training_videos.py
│   ├── marketplace_items.py / me_marketplace.py
│   ├── reports.py / metrics.py
│   ├── notifications.py / me_push.py / admin_push.py
│   ├── photos.py
│   ├── enrollment.py
│   └── partners.py / global_partners.py
│
├── services/                ← Lógica de negócio (38 serviços)
│   ├── [Gamificação]        execution_service, mission_service,
│   │                        mission_complete_service, trophy_service,
│   │                        leveling_service, login_streak_service
│   ├── [Conteúdo]           lesson_service, technique_service,
│   │                        training_video_service, training_feedback_service
│   ├── [Presença]           attendance_service, attendance_realtime
│   ├── [Academia]           academy_service, professor_service,
│   │                        professor_impact_service
│   ├── [Usuário]            user_service, push_token_service, fcm_service
│   ├── [Marketplace]        marketplace_item_service, partner_service
│   ├── [Notificações]       notification_service, trophy_notification_service,
│   │                        execution_notification_service
│   └── [Sistema]            audit_service, metrics_service,
│                            photos_service, manual_trophy_service,
│                            enrollment_service, weekly_kit_service
│
└── tasks/                   ← Celery (6 arquivos)
    ├── execution_tasks.py   ← escalate + notify professor
    ├── face_recognition_tasks.py ← DeepFace processing
    ├── at_risk_tasks.py     ← weekly alert
    ├── streak_tasks.py      ← streak push
    └── photo_tasks.py       ← expire restrictions
```

### 3.2 Frontend Flutter

```
viewer/lib/
├── main.dart                ← App bootstrap, Hive init, Firebase init
├── app_theme.dart           ← Material 3 theme
│
├── models/                  ← 33 Dart data classes (fromJson/toJson)
│
├── services/
│   ├── api_service.dart     ← HTTP client com cache + retry
│   ├── auth_service.dart    ← JWT storage (Hive), refresh
│   ├── push_notification_service.dart ← FCM + token registration
│   └── daily_checkin_service.dart
│
├── screens/
│   ├── auth/                ← Login, PublicRegistration
│   ├── student/             ← Home, Lessons, Executions, Trophies,
│   │                           Attendance, Marketplace, Videos
│   ├── academy/             ← Panel, Attendance Hub, Face Recognition,
│   │                           Professor Review, Manual Trophies
│   ├── admin/               ← CRUD completo (técnicas, lições, missões,
│   │                           troféus, usuários, academias, parceiros)
│   └── notifications_screen.dart
│
├── widgets/                 ← 27 componentes reutilizáveis
│   ├── [Layout]             AppCard, AppStandardAppBar, AppListScaffold,
│   │                        HeaderWidget, BottomNavigationWidget
│   ├── [Gamificação]        MissionCard, XpBar, StreakWidget,
│   │                        WeeklyMissionPath, RewardScreen
│   ├── [Guards]             RoleGuard, AccountFrozenBanner
│   └── [Utilitários]        YoutubePlayerEmbed, SearchableDropdown,
│                            OpponentPickerSheet, PwaInstallBanner
│
└── features/
    ├── trophies/            ← Trophy Shelf (Clean Architecture local)
    │   ├── domain/usecases/ ← SyncTrophies, ClearCache, Delete
    │   └── presentation/    ← ShelfBackground, ShelfRow, TrophySlot
    └── photos/              ← OctoPhotos feed
        ├── domain/          ← Repository interface
        └── presentation/    ← PhotosFeedScreen, StudentSearchPhotos
```

---

## 4. Mapa de Dependências

### 4.1 Dependências Python (backend)

```
FastAPI 0.115
  └── Pydantic 2.x (schemas)
  └── Uvicorn (ASGI server)
  └── slowapi (rate limiting)

SQLAlchemy 2.0 (async)
  └── asyncpg (PostgreSQL driver)
  └── psycopg2-binary (sync, migrations)
  └── Alembic (migrations)

Celery 5.x
  └── Redis (broker + backend)
  └── Kombu (messaging)

DeepFace
  └── TensorFlow (GPU opcional)
  └── OpenCV
  └── NumPy / Pillow
  └── FaceNet512 model (download automático)

python-jose (JWT)
  └── cryptography

passlib (password hashing)
  └── bcrypt

google-auth (FCM)
  └── requests (HTTP)

Prometheus (metrics)
  └── prometheus-fastapi-instrumentator
```

### 4.2 Dependências Flutter (frontend)

```
Flutter SDK (Scoop)
  │
  ├── State
  │   └── flutter_riverpod 2.5
  │
  ├── Storage
  │   ├── hive 2.2 (local DB)
  │   └── shared_preferences 2.2
  │
  ├── Firebase
  │   ├── firebase_core 4.6
  │   └── firebase_messaging 16.1
  │
  ├── UI
  │   ├── google_fonts 6.2
  │   ├── fl_chart 0.69 (gráficos)
  │   ├── qr_flutter 4.1 (geração QR)
  │   └── mobile_scanner 6.0 (scan QR)
  │
  ├── Media
  │   ├── image_picker 1.1
  │   ├── image_cropper 8.0
  │   └── youtube_player_flutter
  │
  └── Network
      └── http 1.2
```

### 4.3 Acoplamento entre módulos (backend)

```
routes/ ──depende de──► services/ ──depende de──► models/
   │                        │                        │
   │                        ├──► core/leveling.py    │
   │                        ├──► core/graduation.py  │
   │                        └──► core/app_time.py    │
   │                                                  │
   └──depende de──► core/auth_deps.py ──► models/user │
   └──depende de──► schemas/          ──► models/     │
                                                       │
tasks/ ──depende de──► services/      ──depende de──► │
       ──depende de──► models/ (direto — ver débito)
```

**Problema identificado:** `tasks/` acessa `models/` diretamente, bypassando `services/`. Isso cria acoplamento bidirecional.

---

## 5. Modelos de Dados

### 5.1 Entidades Principais e Relacionamentos

```
Academy (1)──────────────────────────────────────────(N) User
    │                                                       │
    ├──(N) Technique                                        ├──(N) MissionUsage
    │       └──(N) Lesson                                   ├──(N) TechniqueExecution
    │                                                       ├──(N) UserTrophyEarned
    ├──(N) Mission ──────────────────────────────────────── │
    │       ├── technique_id (FK)                           ├──(N) AttendanceRecord
    │       ├── lesson_id (FK)                              ├──(N) LessonProgress
    │       └── weekly_kit_id (FK)                          ├──(N) TrainingVideoDailyView
    │                                                       └──(N) UserLoginDay
    ├──(N) Trophy
    │       ├── technique_id (FK)
    │       └──(N) UserTrophyEarned
    │
    ├──(N) AttendanceSession
    │       └──(N) AttendanceRecord
    │
    ├──(N) TrainingVideo
    │       └──(N) TrainingVideoDailyView
    │
    ├──(N) WeeklyTechniqueKit (slots 0-4)
    │
    ├──(N) AcademyMarketplaceItem
    ├──(N) Partner
    └──(N) AcademyPhoto

TechniqueExecution
    ├── user_id (executor)
    ├── opponent_id (adversário)
    ├── mission_id (FK)
    ├── lesson_id (FK)
    ├── technique_id (FK)
    ├── status: pending_confirmation | pending_professor_review | confirmed | rejected
    └── confirmed_by (professor_id ou opponent_id)

User
    ├── role: aluno | professor | gerente_academia | administrador | supervisor
    ├── graduation: white | blue | purple | brown | black
    ├── reward_level (nível de gamificação)
    └── account_frozen (bool)
```

### 5.2 Tabelas de Gamificação

```
MissionUsage
  ├── user_id
  ├── mission_id
  ├── lesson_id
  ├── opened_at
  ├── completed_at
  └── usage_type: before_training | after_training

UserTrophyEarned
  ├── user_id
  ├── trophy_id
  ├── tier: gold | silver | bronze
  └── earned_at

ManualTrophy (troféu livre, sem técnica associada)
  ├── academy_id
  ├── user_id
  ├── name
  └── earned_at
```

---

## 6. Padrões Arquiteturais

### Utilizados

| Padrão | Onde | Avaliação |
|--------|------|-----------|
| **Service Layer** | `services/` encapsula toda lógica | ✅ Bem aplicado |
| **Repository (implícito)** | Services fazem queries SQLAlchemy | ⚠️ Sem interface formal |
| **Dependency Injection** | FastAPI `Depends()` | ✅ Correto |
| **Async I/O** | SQLAlchemy async + asyncpg | ✅ Correto |
| **CQRS leve** | Queries vs Commands em services separados | ⚠️ Inconsistente |
| **Domain Events (ad-hoc)** | Notificações pós-execução | ⚠️ Acoplado ao service |
| **Soft Delete** | `deleted_at` em entidades críticas | ✅ Correto |
| **Audit Log** | `AuditLog` com snapshots JSON | ✅ Bom |
| **Feature Flags** | `face_recognition_enabled`, `octophotos_enabled` | ✅ Correto |
| **Clean Architecture local** | `features/trophies/` no Flutter | ✅ Bom início |
| **Rate Limiting** | slowapi | ✅ Correto |

### Não utilizados (oportunidades)

| Padrão | Benefício Esperado |
|--------|-------------------|
| Event Bus / Domain Events | Desacoplar notificações das execuções |
| Repository interface (ABC) | Testabilidade via mock |
| CQRS explícito | Escalar leitura separada de escrita |
| Cache distribuído (Redis) | Hoje cache é in-memory por processo |

---

## 7. Fluxos Críticos

### 7.1 Cálculo de Pontos

```python
# core/graduation.py
graduation_factors = {
    "white":  1.0,
    "blue":   1.3,
    "purple": 1.6,
    "brown":  1.9,
    "black":  2.5,
}

# core/leveling.py
points = base_points × graduation_factor(opponent) × slot_multiplier

# Limites: MIN=10, MAX=50 por execução
# reward_level = floor(total_points / threshold)
```

### 7.2 Escalação de Execuções

```
TechniqueExecution.created_at + 4 dias
  → Celery task (04:00 UTC)
  → status: pending_confirmation → pending_professor_review
  → Push para professor
  → Professor pode confirmar, rejeitar ou aumentar pontos
```

### 7.3 Missões Semanais

```
Academy define:
  slot_1 = Técnica A, multiplier=1.0
  slot_2 = Técnica B, multiplier=1.5
  slot_3 = Técnica C, multiplier=2.0

Sistema cria Mission por slot (start=segunda, end=domingo)
Aluno escolhe turma → UserWeeklyKitChoice vincula aluno ao kit

Missão é exibida no StudentHomeScreen filtrada por:
  - academy_id do aluno
  - reward_level do aluno (missões têm min_level)
  - Data atual entre start_date e end_date
```

---

## 8. Débitos Técnicos e Melhorias Priorizadas

### 🔴 CRÍTICO — Impacta confiabilidade, segurança ou escalabilidade imediata

---

**C1 — Cache in-memory por processo (não distribuído)**

- **Problema:** `app/core/cache.py` usa dicionário Python na memória do processo Uvicorn. Em múltiplos workers ou após restart, o cache é zerado. Dados como analytics de academia podem ficar desatualizados por minuto e depois sumir.
- **Impacto:** Inconsistência entre workers; perda de cache no deploy.
- **Solução:** Migrar para `aiocache` com backend Redis, reutilizando a instância já existente.
- **Esforço:** Médio (1-2 dias).

---

**C2 — `tasks/` acessa `models/` diretamente (bypassa services)**

- **Problema:** Tarefas Celery em `execution_tasks.py` e `face_recognition_tasks.py` importam e fazem queries SQLAlchemy direto, duplicando lógica que existe em `services/`.
- **Impacto:** Bug introduzido em um service não reflete na task. Dificulta testes unitários.
- **Solução:** Tasks devem chamar `await execution_service.escalate()`, etc.
- **Esforço:** Médio (1 dia).

---

**C3 — Celery Worker rodando com `pool=solo` (concurrency=1)**

- **Problema:** Necessário por causa do TensorFlow (DeepFace), mas significa que todas as tarefas são serializadas. Se um job de reconhecimento facial demora 30s, alertas de streak ficam na fila.
- **Impacto:** Em pico, pushes notificações podem atrasar.
- **Solução:** Separar em dois workers: `celery_ai` (solo, para DeepFace) e `celery_default` (prefork, para o resto). Rotear tasks com `task_routes`.
- **Esforço:** Médio (1 dia).

---

**C4 — Sem testes automatizados visíveis**

- **Problema:** `pyproject.toml` configura pytest mas não há `tests/` no repo. O sistema de pontos, escalação e geração de níveis é lógica crítica sem cobertura verificável.
- **Impacto:** Regressões silenciosas em deploy.
- **Solução:** Pelo menos testes unitários para `leveling.py`, `graduation.py` e `execution_service.py`.
- **Esforço:** Alto (2-4 dias para cobertura mínima aceitável).

---

**C5 — JWT sem rotação de tokens (refresh token)**

- **Problema:** `auth.py` emite apenas `access_token`. Quando expira, usuário precisa fazer login novamente. Não há `refresh_token`.
- **Impacto:** UX ruim para sessões longas; tokens de longa duração são risco de segurança se comprometidos.
- **Solução:** Implementar `POST /auth/refresh` com token de curta duração no header e refresh de longa duração em cookie httpOnly.
- **Esforço:** Médio (1 dia).

---

### 🟡 IMPORTANTE — Melhora qualidade, manutenibilidade ou performance

---

**I1 — 36 arquivos de routes sem versionamento de API**

- **Problema:** Todos os endpoints estão em `/` raiz (ex: `/executions`, `/trophies`). Sem prefixo `/v1/`. Uma mudança breaking afeta todos os clientes imediatamente.
- **Solução:** Prefixar com `/api/v1/` via `APIRouter(prefix="/api/v1")`. Manter alias legacy temporário.
- **Esforço:** Baixo (meio dia).

---

**I2 — Schemas Pydantic duplicados entre request e response**

- **Problema:** Vários schemas têm `Create`, `Read`, `Update` quase idênticos com 80%+ de campos iguais. Em 34 schemas isso gera ~200 linhas repetidas.
- **Solução:** Usar herança Pydantic: `TrophyBase` → `TrophyCreate(TrophyBase)` → `TrophyRead(TrophyBase)`.
- **Esforço:** Baixo (1 dia).

---

**I3 — `api_service.dart` é um god object**

- **Problema:** O serviço HTTP do Flutter centraliza todas as chamadas de API em um único arquivo. Com 150+ endpoints, isso resulta em um arquivo imenso difícil de manter.
- **Solução:** Separar por domínio: `ExecutionApiService`, `TrophyApiService`, `AttendanceApiService`, etc., com `ApiService` como base com lógica de autenticação e retry.
- **Esforço:** Alto (2-3 dias, risco de regressão).

---

**I4 — Sem paginação em listagens críticas**

- **Problema:** Endpoints como `GET /executions/my`, `GET /trophies/gallery/{user_id}` e `GET /notifications` aparentemente não usam paginação consistente. Com crescimento de dados, retornam payloads crescentes.
- **Solução:** Padronizar `?page=1&page_size=20` usando `core/list_pagination.py` existente.
- **Esforço:** Médio (1-2 dias).

---

**I5 — DeepFace baixa modelos em runtime**

- **Problema:** Na primeira execução após rebuild do container, o TensorFlow baixa o modelo FaceNet512 (~90MB). Se sem internet no servidor, o worker falha silenciosamente.
- **Solução:** Pré-baixar o modelo no `Dockerfile` e incluir no volume persistente. Variável `DEEPFACE_HOME` aponta para path local.
- **Esforço:** Baixo (meio dia).

---

**I6 — Sem índices explícitos em colunas de query frequente**

- **Problema:** Colunas como `technique_execution.status`, `technique_execution.user_id + status`, `mission_usage.user_id + mission_id` são filtradas frequentemente mas provavelmente não têm índices compostos.
- **Solução:** Adicionar migration Alembic com `Index('ix_executions_user_status', 'user_id', 'status')` nas tabelas críticas.
- **Esforço:** Baixo (meio dia).

---

**I7 — Ausência de health check profundo**

- **Problema:** `GET /health` existe mas provavelmente retorna apenas `{"status": "ok"}` sem verificar conectividade com PostgreSQL, Redis e Celery.
- **Solução:** Health check que testa `SELECT 1` no PG, ping no Redis e verifica fila Celery não está presa.
- **Esforço:** Baixo (meio dia).

---

**I8 — `ManualTrophy` e `UserTrophyEarned` são entidades separadas sem polimorfismo**

- **Problema:** A tela de galeria de troféus precisa mesclar `ManualTrophy` (livre) com `UserTrophyEarned` (gamificado) em memória. Se crescerem independentemente, relatórios ficam inconsistentes.
- **Solução:** View SQL ou `UNION` na query do `trophy_service.get_trophy_home_summary()` para retornar os dois tipos uniformemente.
- **Esforço:** Baixo (meio dia).

---

### 🔵 OPCIONAL — Qualidade de vida, escalabilidade futura

---

**O1 — Sem monitoramento de filas Celery**

- **Descrição:** Sem Flower ou dashboard para visualizar filas, tasks atrasadas ou workers mortos.
- **Solução:** Adicionar `flower` no `docker-compose.yml` (`:5555`, protegido por senha).
- **Esforço:** Mínimo.

---

**O2 — Logs não são estruturados (JSON)**

- **Descrição:** Logs em texto livre dificultam filtragem em produção. Com Coolify/Docker, logs vão para stdout sem estrutura.
- **Solução:** Configurar `logging_config.py` para emitir JSON com campos `level`, `timestamp`, `request_id`, `user_id`.
- **Esforço:** Baixo.

---

**O3 — Flutter não usa `go_router` (navegação declarativa)**

- **Descrição:** Com 77 screens e navegação baseada em `Navigator.push`, deep links e URL no Flutter Web são difíceis. PWA share links não funcionam.
- **Solução:** Migrar para `go_router` com routes nomeadas.
- **Esforço:** Alto (risco de regressão).

---

**O4 — Sem CDN para assets de vídeo/imagem**

- **Descrição:** Avatares, logos e fotos de academia são servidos diretamente pelo container FastAPI (via `app_media` volume). Em produção com muitos alunos, isso consome banda do servidor.
- **Solução:** Configurar Cloudflare R2 ou Backblaze B2 como storage com CDN.
- **Esforço:** Médio.

---

**O5 — `AuditLog` cresce sem retenção definida**

- **Descrição:** A tabela `audit_log` armazena snapshots JSON de todas as alterações. Sem política de retenção, pode crescer indefinidamente.
- **Solução:** Celery task mensal que arquiva registros com >90 dias para cold storage ou deleta.
- **Esforço:** Baixo.

---

**O6 — Features módulo `features/trophies/` e `features/photos/` não estão padronizadas**

- **Descrição:** `features/trophies/` usa Clean Architecture (usecases, domain), mas `features/photos/` é mais simples. O resto do app usa o padrão antigo (screens + services). Inconsistência confunde quem vai adicionar features.
- **Solução:** Documentar qual padrão usar para novas features. Ou migrar gradualmente.
- **Esforço:** Médio (documentação agora, migração futura).

---

**O7 — `weekly_kit_service.py` e `mission_service.py` têm responsabilidades sobrepostas**

- **Descrição:** A geração de missões semanais envolve lógica espalhada entre `academy_service.ensure_weekly_missions_if_needed()`, `weekly_kit_service` e `mission_service`. Difícil rastrear onde a missão é criada.
- **Solução:** Consolidar em `weekly_kit_service` com responsabilidade única e clara.
- **Esforço:** Médio.

---

## Resumo Executivo

| Categoria | Quantidade | Prioridade |
|-----------|-----------|-----------|
| Crítico | 5 itens | Resolver antes de escalar |
| Importante | 8 itens | Próximos 2-3 sprints |
| Opcional | 7 itens | Backlog longo prazo |

**Ações imediatas recomendadas (semana 1):**
1. `C3` — Separar workers Celery (AI vs default) — impacta confiabilidade de push
2. `C1` — Migrar cache para Redis — impacta consistência entre deploys
3. `I6` — Adicionar índices compostos — impacto imediato em queries lentas

**Ações de qualidade (semana 2-3):**
4. `C4` — Testes para lógica de pontos e escalação
5. `C2` — Tasks chamam services, não models diretamente
6. `I4` — Paginação consistente em listagens

**Ações estratégicas (longo prazo):**
7. `C5` — Refresh token
8. `I1` — Versionamento de API
9. `I3` — Refatorar `api_service.dart`
