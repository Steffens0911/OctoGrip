# FlowRoll / OctoGrip — Guia de Recuperação de Desastre

> Última atualização: 2026-05-30

Este documento responde à pergunta: **"O servidor morreu. Como recoloco tudo no ar do zero?"**

---

## 1. Visão Geral do Sistema

| Componente | Tecnologia | Container |
|---|---|---|
| API (backend) | FastAPI + Python 3.12 | `jjb_api` |
| Banco de dados | PostgreSQL 16 | `jjb_postgres` |
| Fila de tarefas | Celery + Redis 7 | `jjb_celery_worker` + `jjb_celery_beat` |
| Frontend | Flutter Web servido por Nginx | `jjb_viewer` |
| Broker/Cache | Redis 7 | `jjb_redis` |

Tudo orquestrado via `docker-compose.yml` na raiz do repositório.

---

## 2. O Que Pode Se Perder (e onde está salvo)

| Item | Onde está | Risco |
|---|---|---|
| Código-fonte | GitHub (`main`) | Baixo — push regular protege |
| Dados dos alunos (banco) | Volume Docker `postgres_data` no servidor | **ALTO** — se o servidor morrer sem backup, perde tudo |
| Fotos/mídias dos alunos | Volume Docker `api_media` no servidor | **ALTO** — mesmo risco do banco |
| Variáveis de ambiente (`.env`) | Apenas no servidor | **ALTO** — não está no git |
| Firebase Service Account (`secrets/`) | Apenas no servidor | **ALTO** — não está no git |
| Configuração do Coolify | Painel do Coolify | Médio — pode ser reconfigurado |

---

## 3. Segredos que Precisam Estar Salvos (fora do servidor)

Guarde estas informações em um gerenciador de senhas (ex: Bitwarden):

```
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=
JWT_SECRET=
CORS_ORIGINS=
API_BASE_URL=
FIREBASE_PROJECT_ID=
FIREBASE_WEB_APP_ID=
FIREBASE_WEB_API_KEY=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_AUTH_DOMAIN=
FIREBASE_STORAGE_BUCKET=
FCM_VAPID_KEY=
FIREBASE_SERVICE_ACCOUNT_PATH=
REDIS_URL=
SENTRY_DSN=
PGSSLMODE=
```

Além das variáveis, salvar também o arquivo `secrets/firebase-service-account.json` (JSON da service account do Firebase).

---

## 4. Backup Manual do Banco (fazer agora e periodicamente)

```bash
# Dentro do servidor, com os containers rodando:
docker exec jjb_postgres pg_dump \
  -U jjb \
  -d jjb_db \
  -F c \
  -f /tmp/backup_$(date +%Y%m%d_%H%M).dump

# Copiar o dump para a máquina local:
docker cp jjb_postgres:/tmp/backup_YYYYMMDD_HHMM.dump ./backup_YYYYMMDD.dump
```

Após baixar, subir para Google Drive ou similar.

---

## 5. Restaurar o Banco a Partir de um Dump

```bash
# Com o container postgres rodando:
docker cp backup_YYYYMMDD.dump jjb_postgres:/tmp/backup.dump

docker exec jjb_postgres pg_restore \
  -U jjb \
  -d jjb_db \
  --clean \
  --if-exists \
  /tmp/backup.dump
```

---

## 6. Recriar o Ambiente do Zero

### 6.1 Requisitos no servidor
- Docker + Docker Compose
- Git
- Acesso ao GitHub

### 6.2 Passo a passo

```bash
# 1. Clonar o repositório
git clone https://github.com/Steffens0911/AppBaby.git
cd AppBaby

# 2. Criar o arquivo .env com os segredos salvos (ver seção 3)
cp .env.example .env
# Editar .env com os valores reais

# 3. Restaurar o arquivo Firebase
mkdir -p secrets
# Copiar o firebase-service-account.json para secrets/

# 4. (Apenas se tiver dump do banco) Subir só o postgres primeiro
docker compose up -d postgres
# Aguardar ficar healthy, depois restaurar (ver seção 5)

# 5. Subir todos os serviços
docker compose up -d

# 6. Verificar se a API está saudável
curl http://localhost:8001/health
```

### 6.3 Migrations

As migrations são executadas automaticamente pelo entrypoint da API no startup.
Arquivo: `deploy/entrypoint.sh`

Se precisar rodar manualmente:
```bash
docker exec jjb_api python -m app.scripts.run_migrations
```

---

## 7. Rebuild das Imagens Docker

### Backend (API + Celery)
```bash
docker compose build api celery-worker celery-beat
docker compose up -d
```

### Frontend (Viewer Flutter)
O viewer passa pelo GitHub Actions antes do deploy no Coolify.

Para rebuild manual local:
```bash
cd viewer
flutter.bat build web --release
cd ..
docker compose build viewer
docker compose up -d viewer
```

> Flutter está instalado via Scoop. Usar `flutter.bat`, não `flutter`.

---

## 8. Pipeline de Deploy (fluxo normal)

```
Commit local
    │
    ├─── API/Backend ──► git push ──► Coolify (deploy direto)
    │
    └─── Frontend ──► git push ──► GitHub Actions (build Flutter) ──► ✅ ──► Coolify
```

O Coolify monitora o repositório e faz o deploy automaticamente após o push.

---

## 9. Portas dos Serviços

| Serviço | Porta externa | Porta interna |
|---|---|---|
| API | 8001 | 8000 |
| Frontend (viewer) | 8080 | 80 |
| PostgreSQL | 5432 | 5432 |
| Redis | 6379 | 6379 |

---

## 10. Tarefas Agendadas (Celery Beat)

| Tarefa | Horário |
|---|---|
| Limpeza de face recognition | 03:00 UTC diário |
| Expiração de sessões de presença | A cada 30 minutos |
| Escalada de execuções | 04:00 UTC diário |
| Expiração de restrições de foto | A cada 30 minutos |

---

## 11. Checklist de Saúde Pós-Restauração

- [ ] `curl http://localhost:8001/health` retorna 200
- [ ] Login funciona no viewer (http://localhost:8080)
- [ ] Alunos aparecem na listagem da academia
- [ ] Celery worker está rodando: `docker logs jjb_celery_worker`
- [ ] Sem erros críticos nos logs: `docker compose logs --tail=50`

---

## 12. Contatos e Referências

| Recurso | Onde |
|---|---|
| Repositório | GitHub: Steffens0911/AppBaby |
| Deploy | Coolify (painel do servidor) |
| Push notifications | Firebase Console |
| Error tracking | Sentry (se `SENTRY_DSN` configurado) |
