# Octogrip

Plataforma SaaS de gamificação para academias de jiu-jitsu. Alunos ganham pontos e troféus ao executar e confirmar técnicas; professores controlam presença (QR + reconhecimento facial); administradores gerenciam todo o conteúdo e relatórios.

---

## Índice

1. [Visão geral do sistema](#1-visão-geral-do-sistema)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Setup local (desenvolvimento)](#3-setup-local-desenvolvimento)
4. [Variáveis de ambiente](#4-variáveis-de-ambiente)
5. [Setup de produção](#5-setup-de-produção)
6. [Processo de deploy](#6-processo-de-deploy)
7. [Estrutura do banco de dados](#7-estrutura-do-banco-de-dados)
8. [Serviços externos](#8-serviços-externos)
9. [Estrutura do repositório](#9-estrutura-do-repositório)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Visão geral do sistema

```
Internet
  │
  ▼
[Flutter Web / Mobile]  ←── porta 8080
  │  HTTPS / REST JSON
  ▼
[FastAPI :8001] ──── [PostgreSQL 16 :5432]
  │                        │
  │               [Redis 7 :6379]
  │                   │
  └──────── [Celery Worker + Beat]
                  │
         [Firebase Cloud Messaging]
```

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Frontend | Flutter / Dart | 3.x |
| State management | Riverpod | 2.5 |
| Backend API | FastAPI | 0.115 |
| ORM | SQLAlchemy async | 2.0 |
| Banco de dados | PostgreSQL | 16 |
| Cache / Broker | Redis | 7 |
| Workers assíncronos | Celery | 5.x |
| Reconhecimento facial | DeepFace + TensorFlow (FaceNet512) | — |
| Push notifications | Firebase Cloud Messaging | — |
| Containers | Docker Compose | — |
| CI/CD | GitHub Actions → Coolify | — |

### Perfis de usuário

| Role | Permissões principais |
|------|----------------------|
| `aluno` | Ver missões, registrar execuções, assistir vídeos, confirmar técnicas |
| `professor` | Revisar execuções, abrir sessão de presença, reconhecimento facial |
| `gerente` | Tudo do professor + gestão de alunos e relatórios |
| `admin` | Tudo + CRUD global, backup/restore, impersonation |
| `supervisor` | Acesso somente-leitura a múltiplas academias |

---

## 2. Pré-requisitos

### Para rodar com Docker (recomendado)

- **Docker Desktop** ≥ 24 com Docker Compose v2
- **Git**
- **4 GB de RAM disponível** (o container do Celery Worker carrega TensorFlow/FaceNet512)

### Para desenvolvimento sem Docker

- **Python** 3.12
- **PostgreSQL** 16
- **Redis** 7
- **Flutter SDK** 3.x (instalado via Scoop no Windows: `scoop install flutter`)

---

## 3. Setup local (desenvolvimento)

### 3.1 Clonar e configurar variáveis

```bash
git clone https://github.com/steffens0911/AppBaby.git
cd AppBaby

cp .env.example .env
# Edite .env com suas credenciais (veja seção 4)
```

### 3.2 Subir com Docker Compose

```bash
docker compose up -d
```

Isso sobe seis containers:

| Container | Serviço | Porta exposta |
|-----------|---------|---------------|
| `jjb_postgres` | PostgreSQL 16 | 5432 |
| `jjb_redis` | Redis 7 | 6379 |
| `jjb_api` | FastAPI + Uvicorn (4 workers) | **8001** |
| `jjb_celery_worker` | Celery Worker (pool=solo) | — |
| `jjb_celery_beat` | Celery Beat (scheduler) | — |
| `jjb_viewer` | Flutter Web / Nginx | **8080** |

> **Nota sobre o Viewer:** o container do viewer precisa que o Flutter Web já tenha sido buildado.
> No setup local, faça o build antes de subir:
> ```bash
> cd viewer
> flutter.bat build web --release --tree-shake-icons   # Windows
> flutter build web --release --tree-shake-icons       # Linux/Mac
> cd ..
> docker compose up -d --build viewer
> ```

### 3.3 Migrations e seed

O entrypoint da API (`deploy/entrypoint.sh`) roda `python -m app.bootstrap` automaticamente na inicialização quando `BOOTSTRAP_ON_STARTUP=true` (padrão). O bootstrap aplica migrations do Alembic e, se `SEED_ON_STARTUP=true`, insere dados iniciais.

Para rodar migrations manualmente:

```bash
docker compose exec api alembic upgrade head
```

Para criar uma nova migration:

```bash
docker compose exec api alembic revision --autogenerate -m "descricao_da_mudanca"
```

### 3.4 Verificar que está funcionando

```bash
# Health check da API
curl http://localhost:8001/health

# Documentação Swagger (abrir no browser)
# http://localhost:8001/docs

# Frontend (abrir no browser)
# http://localhost:8080
```

### 3.5 Rodar testes

```bash
pip install -r requirements-test.txt

# Testes com cobertura
pytest -v --cov=app --cov-report=term-missing

# Lint
ruff check app/ tests/
ruff format --check app/ tests/
```

### 3.6 Desenvolvimento sem Docker (somente API)

```bash
# Instale as dependências Python
pip install -r requirements.txt

# Configure .env com DATABASE_URL apontando para localhost
# Ex: DATABASE_URL=postgresql://jjb:senha@localhost:5432/jjb_db

# Suba Postgres e Redis separadamente via Docker
docker compose up -d postgres redis

# Rode a API
uvicorn app.main:app --reload --port 8000
```

---

## 4. Variáveis de ambiente

Copie `.env.example` para `.env` e preencha os valores marcados como **OBRIGATÓRIO**.

### Banco de dados

| Variável | Padrão (dev) | Obrigatório em prod | Descrição |
|----------|-------------|---------------------|-----------|
| `POSTGRES_USER` | `jjb` | ✓ | Usuário do PostgreSQL |
| `POSTGRES_PASSWORD` | `dev_local_only` | ✓ | Senha (use valor forte) |
| `POSTGRES_DB` | `jjb_db` | ✓ | Nome do banco |
| `DATABASE_URL` | `postgresql://jjb:...@postgres:5432/jjb_db` | ✓ | URL completa de conexão |
| `DB_POOL_SIZE` | `8` | — | Conexões no pool |
| `DB_MAX_OVERFLOW` | `4` | — | Conexões extras no pico |
| `PGSSLMODE` | `disable` | — | Modo SSL do libpq |

### Segurança

| Variável | Padrão (dev) | Obrigatório em prod | Descrição |
|----------|-------------|---------------------|-----------|
| `JWT_SECRET` | `dev-local-only...` | ✓ | Mínimo 32 chars. Gere com: `python -c "import secrets; print(secrets.token_urlsafe(64))"` |
| `CORS_ORIGINS` | `[]` | ✓ | JSON array: `["https://app.seudominio.com"]`. `[]` libera localhost via regex. `["*"]` é ignorado. |
| `QR_SECRET` | — | ✓ (presença QR) | HMAC-SHA256 para QR codes. Gere igual ao JWT_SECRET. |
| `ACCOUNT_LOCKOUT_ATTEMPTS` | `5` | — | Tentativas de login antes de bloquear conta |
| `ACCOUNT_LOCKOUT_MINUTES` | `15` | — | Duração do bloqueio em minutos |

### Redis / Celery

| Variável | Padrão (dev) | Descrição |
|----------|-------------|-----------|
| `REDIS_URL` | `redis://redis:6379/0` | URL do Redis (broker + backend Celery) |

### Firebase (push notifications)

| Variável | Obrigatório | Descrição |
|----------|-------------|-----------|
| `FIREBASE_PROJECT_ID` | Para push | ID do projeto Firebase |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Para push | Caminho para o JSON da service account (ex: `secrets/firebase-service-account.json`) |

### Flutter Web (build-time args)

Estas variáveis são passadas como `--build-arg` ao Docker e injetadas no `index.html` do Flutter Web:

| Variável | Descrição |
|----------|-----------|
| `API_BASE_URL` | URL da API acessível pelo browser (ex: `https://api.seudominio.com`) |
| `FIREBASE_WEB_APP_ID` | App ID do Firebase Web |
| `FIREBASE_WEB_API_KEY` | API key do Firebase Web |
| `FIREBASE_MESSAGING_SENDER_ID` | Sender ID para FCM Web |
| `FIREBASE_AUTH_DOMAIN` | Auth domain do Firebase |
| `FIREBASE_STORAGE_BUCKET` | Storage bucket do Firebase |
| `FCM_VAPID_KEY` | Chave VAPID para FCM Web push |

### Comportamento da aplicação

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `ENVIRONMENT` | `development` | `development` ou `production` |
| `APP_TIMEZONE` | `America/Sao_Paulo` | Fuso para streak, relatórios e semana ISO |
| `SEED_ON_STARTUP` | `false` | Inserir dados iniciais no startup |
| `BOOTSTRAP_ON_STARTUP` | `true` | Rodar migrations no startup |
| `LOGIN_STREAK_BONUS_POINTS` | `50` | Pontos bônus por streak de 7 dias |
| `LOGIN_STREAK_BONUS_INTERVAL_DAYS` | `7` | Intervalo em dias para bônus de streak |
| `LOGIN_RATE_LIMIT` | `10/minute` | Rate limit no endpoint de login (formato slowapi) |
| `BACKUP_DOWNLOAD_RATE_LIMIT` | `3/hour` | Rate limit para download de backup |
| `FACE_JOBS_DIR` | `/tmp/face_jobs` | Diretório temporário para jobs de reconhecimento facial |
| `FACE_MAX_IMAGE_SIDE` | `1280` | Dimensão máxima de imagem para reconhecimento facial |

### Observabilidade

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `LOG_LEVEL` | `INFO` | Nível de log (DEBUG, INFO, WARNING, ERROR) |
| `LOG_FORMAT` | `text` | Formato de log: `text` ou `json` |
| `SENTRY_DSN` | — | DSN do Sentry para error tracking (opcional) |
| `ENABLE_METRICS` | `true` | Habilitar endpoint `/metrics` (Prometheus) |

### Com Caddy (HTTPS automático)

Se usar o override `docker-compose.caddy.yml`, adicione também:

```env
APP_DOMAIN=app.seudominio.com
API_DOMAIN=api.seudominio.com
API_BASE_URL=https://api.seudominio.com
CORS_ORIGINS=["https://app.seudominio.com"]
```

---

## 5. Setup de produção

### 5.1 Servidor recomendado

- **VPS**: 4 vCPU, 8 GB RAM (o Celery Worker usa ~2 GB com TensorFlow)
- **Disco**: 20 GB+ SSD (banco + mídias + imagens Docker)
- **OS**: Ubuntu 22.04 LTS ou Debian 12

### 5.2 Configurar o servidor

```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Logout e login para aplicar o grupo

# Clonar o repositório
git clone https://github.com/steffens0911/AppBaby.git /opt/octogrip
cd /opt/octogrip
```

### 5.3 Preparar secrets

```bash
mkdir -p secrets

# Copie a service account do Firebase
# (Baixe em Firebase Console → Configurações do projeto → Contas de serviço)
cp /caminho/firebase-service-account.json secrets/firebase-service-account.json
chmod 600 secrets/firebase-service-account.json
```

### 5.4 Configurar variáveis de ambiente

```bash
cp .env.example .env
nano .env  # Preencha todas as variáveis obrigatórias
```

Checklist mínimo para produção:

```env
POSTGRES_USER=octogrip
POSTGRES_PASSWORD=<senha_forte_gerada>
POSTGRES_DB=octogrip_db
DATABASE_URL=postgresql://octogrip:<senha>@postgres:5432/octogrip_db

JWT_SECRET=<64_chars_gerados_com_secrets.token_urlsafe>
QR_SECRET=<outro_64_chars>

CORS_ORIGINS=["https://app.seudominio.com"]
ENVIRONMENT=production

FIREBASE_PROJECT_ID=seu-projeto-firebase
FIREBASE_SERVICE_ACCOUNT_PATH=secrets/firebase-service-account.json

API_BASE_URL=https://api.seudominio.com
FIREBASE_WEB_APP_ID=...
FIREBASE_WEB_API_KEY=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_STORAGE_BUCKET=...
FCM_VAPID_KEY=...
```

### 5.5 Subir com HTTPS (Caddy)

```bash
docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d
```

O Caddy obtém certificados TLS automaticamente via Let's Encrypt.

### 5.6 Subir via Coolify

O projeto tem suporte nativo ao Coolify via `docker-compose.coolify.yml`. As imagens são puxadas do GHCR (não há build local no Coolify).

#### Passo a passo no painel Coolify

1. **Conecte o repositório** GitHub via OAuth
2. **Build Pack**: Docker Compose
3. **Docker Compose Location**: `/docker-compose.coolify.yml`
4. **Domínios**:
   - Viewer → porta `80` no container
   - API → porta `8000` no container
5. **Configure as variáveis de ambiente** (lista abaixo)
6. **Preparar a service account do Firebase no host** antes do primeiro deploy:
   ```bash
   mkdir -p /srv/octogrip/secrets
   cp firebase-service-account.json /srv/octogrip/secrets/
   chmod 600 /srv/octogrip/secrets/firebase-service-account.json
   ```

#### Variáveis de ambiente no painel Coolify

| Variável | Obrigatório | Valor de exemplo |
|----------|-------------|-----------------|
| `POSTGRES_PASSWORD` | ✓ | senha forte gerada |
| `JWT_SECRET` | ✓ | `secrets.token_urlsafe(64)` |
| `CORS_ORIGINS` | ✓ | `["https://app.seudominio.com"]` |
| `ENVIRONMENT` | ✓ | `production` |
| `FIREBASE_PROJECT_ID` | Para push | `meu-projeto-firebase` |
| `FIREBASE_SECRETS_HOST_PATH` | Para push | `/srv/octogrip/secrets` (caminho no host da VPS onde fica o JSON da service account) |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Para push | `/app/secrets/firebase-service-account.json` (caminho dentro do container) |
| `POSTGRES_USER` | — | `octogrip` (padrão: `jjb`) |
| `POSTGRES_DB` | — | `octogrip_db` (padrão: `jjb_db`) |
| `REDIS_URL` | — | `redis://redis:6379/0` |
| `LOG_LEVEL` | — | `INFO` |
| `DB_POOL_SIZE` | — | `8` |
| `DB_MAX_OVERFLOW` | — | `4` |
| `SENTRY_DSN` | — | `https://...@sentry.io/...` |

> **Diferença para o docker-compose.yml:** no Coolify as portas **não são publicadas no host** (evita conflito com Traefik/proxy do Coolify). O acesso externo passa pelo proxy reverso do Coolify.

### 5.7 Backup automático

Banco e mídias são backupados diariamente às 3h via `rclone → Google Drive`:

- Script: `/usr/local/bin/backup-jjb.sh`
- Destino: `gdrive:backups/jjb`
- Retenção: 30 dias

Para restaurar um backup: `POST /admin/backup/restore` (aceita ZIP, máximo 512 MB, requer role `admin`).

---

## 6. Processo de deploy

### 6.1 Pipeline automático (GitHub Actions → Coolify)

```
git push main
    │
    ▼
[CI workflow]
  ├── pytest (cobertura ≥ 50%)
  ├── ruff check + format
  └── docker build (verifica)
         │ (só se CI passar)
         ▼
[Build & Push API]
  └── ghcr.io/steffens0911/octogrip-api:latest
         │
         ▼
[Coolify] detecta nova imagem → faz deploy
```

O **viewer (Flutter Web)** tem pipeline separado:

```
git push main (mudanças em viewer/**)
    │
    ▼
[Build Viewer workflow]
  ├── flutter pub get
  ├── Preparar Firebase config
  ├── flutter build web --release
  ├── docker build (Nginx serve)
  └── ghcr.io/steffens0911/octogrip-viewer:latest
         │
         ▼
[Coolify] faz deploy do viewer
```

### 6.2 Deploy manual da API (hotfix)

```bash
# No servidor de produção
cd /opt/octogrip
git pull origin main
docker compose pull api
docker compose up -d --no-deps api
```

### 6.3 Rodar migrations em produção

```bash
docker compose exec api alembic upgrade head
```

### 6.4 Build manual do viewer

```bash
cd viewer
flutter.bat build web --release --tree-shake-icons   # Windows
flutter build web --release --tree-shake-icons       # Linux/Mac
cd ..
docker compose up -d --build viewer
```

---

## 7. Estrutura do banco de dados

### Grupos de tabelas

#### Usuários e autenticação
| Tabela | Descrição |
|--------|-----------|
| `users` | Todos os usuários. Campos principais: `role`, `graduation`, `reward_level`, `account_frozen` |
| `user_login_days` | Registro diário de login para cálculo de streak |
| `user_device_tokens` | Tokens FCM para push notifications |
| `audit_logs` | Snapshots JSON de mudanças importantes |

#### Academias (B2B)
| Tabela | Descrição |
|--------|-----------|
| `academies` | Cada cliente SaaS. Inclui `octophotos_enabled`, `user_photos_quota` |
| `academy_marketplace_items` | Itens para troca de pontos por academia |
| `academy_photos` | Feed de fotos da academia (OctoPhotos) |
| `partners` / `global_partners` | Parceiros locais e globais |

#### Gamificação
| Tabela | Descrição |
|--------|-----------|
| `techniques` | Técnicas de jiu-jitsu |
| `missions` | Missões semanais (slot 1-3, multiplier, semana ISO) |
| `mission_usages` | Uso de missão (before/after training) |
| `technique_executions` | Execução registrada em adversário. Status: `pending_confirmation → confirmed / rejected / pending_professor_review` |
| `trophies` | Troféus associados a técnicas (gold/silver/bronze) |
| `user_trophies_earned` | Troféus conquistados por aluno |
| `manual_trophies` | Troféus concedidos manualmente pelo professor (tier: ouro/prata/bronze) |
| `academy_trophy_templates` | Templates de troféus customizados por academia |
| `academy_trophy_awards` | Concessões de troféus customizados |
| `collective_goals` | Metas coletivas da academia |
| `weekly_technique_kits` / `weekly_kit_items` / `user_weekly_kit_choices` | Kit semanal de técnicas |

#### Conteúdo
| Tabela | Descrição |
|--------|-----------|
| `lessons` | Lições com vídeo e conteúdo |
| `training_videos` | Vídeos de treinamento adicionais |
| `training_video_daily_views` | Contagem de visualizações por dia |
| `training_feedbacks` | Feedback do aluno sobre aulas |

#### Presença
| Tabela | Descrição |
|--------|-----------|
| `attendance_sessions` | Sessão de presença por QR (duração 2h) |
| `attendance_records` | Registro individual (método: qr/facial/manual) |

#### Reconhecimento facial
| Tabela | Descrição |
|--------|-----------|
| `student_face_embeddings` | Embeddings FaceNet512 por aluno |
| `face_recognition_jobs` | Jobs de processamento facial (Celery) |

#### Notificações e inscrição
| Tabela | Descrição |
|--------|-----------|
| `notifications` | Notificações com soft-delete por usuário |
| `enrollment_invites` | Convites de inscrição por academia |
| `pending_enrollments` | Inscrições aguardando aprovação |

### Fórmula de pontos por execução

```
pontos = base_points × graduation_factor(faixa) × slot_multiplier(missão)

graduation_factor: branca=1.0, azul=1.1, roxa=1.2, marrom=1.3, preta=1.5
slot_multiplier:   slot 1=1.0, slot 2=1.2, slot 3=1.5
```

### Ciclo de vida de uma execução

```
Aluno registra execução → status: pending_confirmation
    │
    ├── Adversário confirma → pontos aplicados + troféu verificado
    ├── Adversário rejeita → execução cancelada
    │
    └── +4 dias sem resposta (Celery: escalate_pending_executions_to_professor)
           → status: pending_professor_review
           → push notification para professor
```

---

## 8. Serviços externos

### Firebase (obrigatório para push notifications)

1. Acesse [Firebase Console](https://console.firebase.google.com)
2. Crie (ou selecione) um projeto
3. Ative **Firebase Cloud Messaging**
4. Gere uma **service account**:
   - Configurações do projeto → Contas de serviço → Gerar nova chave privada
5. Salve o JSON em `secrets/firebase-service-account.json`
6. Para o Flutter Web, copie as credenciais da aba "Seus apps → Web"
7. Obtenha a **VAPID key** em Cloud Messaging → Configuração da Web → Certificados web push

### GitHub Container Registry (GHCR)

As imagens Docker são publicadas automaticamente pelo GitHub Actions:

- `ghcr.io/steffens0911/octogrip-api:latest`
- `ghcr.io/steffens0911/octogrip-viewer:latest`

Não requer configuração manual. O Actions usa `GITHUB_TOKEN` automaticamente.

### Coolify (PaaS de deploy)

Configuração no painel:

1. **Fonte**: repositório GitHub (conectar via OAuth)
2. **Arquivo Compose**: `docker-compose.coolify.yml`
3. **Variáveis de ambiente**: preencher todas da seção 5.4
4. **Webhook**: habilitado automaticamente para receber triggers do GitHub Actions

### Sentry (opcional)

1. Crie um projeto Python no [Sentry](https://sentry.io)
2. Copie o DSN
3. Adicione `SENTRY_DSN=https://...@sentry.io/...` no `.env`

### rclone + Google Drive (backup)

Para configurar no servidor de produção:

```bash
rclone config
# Tipo: drive
# Nome: gdrive
# Siga o assistente de autenticação OAuth
```

---

## 9. Estrutura do repositório

```
AppBaby/
├── app/                        # Backend FastAPI
│   ├── core/                   # JWT, rate limit, leveling, fuso, métricas
│   ├── models/                 # SQLAlchemy ORM (32 modelos)
│   ├── schemas/                # Pydantic v2 request/response
│   ├── routes/                 # FastAPI routers (150+ endpoints)
│   ├── services/               # Lógica de negócio (38 serviços)
│   ├── tasks/                  # Tasks Celery (face, streak, at-risk, execuções)
│   ├── config.py               # Settings via Pydantic BaseSettings
│   ├── database.py             # Engines async e sync
│   ├── bootstrap.py            # Init: migrations + seed
│   ├── main.py                 # FastAPI app, middlewares, exception handlers
│   └── migrations/             # Alembic
│
├── viewer/                     # Frontend Flutter Web/Mobile
│   ├── lib/
│   │   ├── models/             # Dart data classes (fromJson/toJson)
│   │   ├── services/           # ApiService, AuthService, PushNotificationService
│   │   ├── screens/            # 77+ telas
│   │   └── widgets/            # 27+ componentes reutilizáveis
│   ├── Dockerfile              # Build Flutter Web + Nginx serve
│   └── pubspec.yaml
│
├── .github/workflows/
│   ├── ci.yml                  # Testes + lint + docker build check
│   ├── build-api.yml           # Build e push da API (após CI passar)
│   └── build-viewer.yml        # Build e push do viewer
│
├── deploy/
│   └── entrypoint.sh           # gosu + bootstrap automático no startup
│
├── secrets/                    # .gitignored — service accounts Firebase
├── celery_app.py               # Celery config + beat schedule
├── docker-compose.yml          # Stack completa (dev)
├── docker-compose.caddy.yml    # Override com HTTPS automático
├── docker-compose.coolify.yml  # Override para Coolify
├── Dockerfile                  # Multi-stage: builder + runtime
├── requirements.txt
├── requirements-test.txt
├── pyproject.toml              # pytest + ruff + coverage
├── .env.example
└── ARCHITECTURE.md             # Arquitetura detalhada + débitos técnicos
```

### Tasks agendadas (Celery Beat)

| Horário (UTC) | Task | Descrição |
|---------------|------|-----------|
| 03:00 diário | `cleanup_face_recognition_temp_data` | Limpa `/tmp/face_jobs` |
| A cada 30 min | `cleanup_expired_sessions` | Remove sessões de presença expiradas |
| 04:00 diário | `escalate_pending_executions_to_professor` | Execuções ≥4 dias sem confirmar → professor |
| 08:00 diário | `notify_professor_pending_reviews` | Push: "X execuções pendentes" |
| 23:00 diário | `send_streak_at_risk_push` | Push para aluno: streak em risco (20h Brasília) |
| Segunda 12:00 | `send_weekly_at_risk_alert` | Push para professor: alunos sem presença há 7+ dias |
| A cada 30 min | `expire_photo_restrictions` | Expira restrições de fotos |

---

## 10. Troubleshooting

### API não inicia — `relation does not exist`

As migrations não rodaram. Execute manualmente:

```bash
docker compose exec api alembic upgrade head
```

### Celery Worker morre com SIGKILL (OOMKilled)

O Worker carrega TensorFlow + FaceNet512 (~1.5 GB RAM). Verifique:

```bash
docker stats jjb_celery_worker
```

Se o limite de memória for atingido, aumente `mem_limit` no `docker-compose.yml` (padrão: `2g`) ou use um servidor com mais RAM.

### Push notifications não chegam

1. Verifique se a service account existe e é válida:
   ```bash
   docker compose exec api python -c "
   import json
   data = json.load(open('secrets/firebase-service-account.json'))
   print('project_id:', data['project_id'])
   "
   ```
2. Confirme que `FIREBASE_PROJECT_ID` no `.env` bate com o `project_id` do JSON
3. Procure erros FCM nos logs do worker:
   ```bash
   docker compose logs celery-worker | grep -i fcm
   ```

### Reconhecimento facial não funciona

```bash
# Ver logs do worker
docker compose logs celery-worker --tail=50

# O modelo FaceNet512 é baixado na primeira execução (~90 MB)
# Para pré-carregar:
docker compose exec celery-worker python -c "
from deepface import DeepFace
DeepFace.build_model('FaceNet512')
print('Modelo carregado com sucesso')
"
```

### CORS bloqueando requests do Flutter Web

Verifique `CORS_ORIGINS` no `.env`. Para produção deve ser a URL exata do viewer:

```env
CORS_ORIGINS=["https://app.seudominio.com"]
```

`["*"]` é ignorado pela API (validator remove em produção). `[]` libera `localhost:*` via regex (somente dev).

### Erro `Permission denied` no Celery Beat

O arquivo de schedule fica em `/app/app_media/celerybeat-schedule`. O entrypoint corrige permissões automaticamente. Se persistir:

```bash
docker compose exec celery-beat sh -c "chown app:app /app/app_media"
```

### Verificar credenciais do banco no container

```bash
docker compose exec api env | grep POSTGRES
```

### Checar saúde de todos os serviços

```bash
docker compose ps
# Todos devem estar "healthy" ou "running"

# API
curl http://localhost:8001/health

# Métricas Prometheus
curl http://localhost:8001/metrics
```

### Resetar banco de dados (desenvolvimento)

```bash
docker compose down -v    # Remove volumes — DESTRÓI TODOS OS DADOS
docker compose up -d
```

### Ver logs em tempo real

```bash
docker compose logs -f api
docker compose logs -f celery-worker
docker compose logs -f celery-beat
```

---

## Documentação adicional

- [ARCHITECTURE.md](ARCHITECTURE.md) — Arquitetura detalhada, débitos técnicos priorizados, diagramas de fluxo
- `http://localhost:8001/docs` — Swagger UI com todos os 150+ endpoints
- `http://localhost:8001/redoc` — ReDoc
