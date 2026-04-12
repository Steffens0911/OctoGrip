# Deploy na VPS Contabo com Coolify (AppBaby)

Este guia descreve como publicar a stack **PostgreSQL + API (FastAPI) + viewer (Flutter Web)** usando [Coolify](https://coolify.io/) numa VPS da Contabo.

## Pré-requisitos

- VPS Contabo com Ubuntu 22.04 ou 24.04 LTS (recomendado: pelo menos 2 vCPU / 4 GB RAM para build do viewer).
- Domínio (ou subdomínios) com DNS a apontar para o IP público da VPS:
  - Ex.: `app.seudominio.com` → viewer
  - Ex.: `api.seudominio.com` → API
- Repositório Git acessível pelo Coolify (GitHub, GitLab, Gitea, etc.).

## 1. VPS Contabo

1. No painel Contabo, anote o **IP público** e garanta acesso **SSH** (porta 22).
2. **Firewall** (Contabo e/ou `ufw` na VPS): permitir pelo menos **22** (SSH), **80** e **443** (HTTP/HTTPS para o proxy do Coolify).
3. Opcional: restringir a porta do painel do Coolify se expuser apenas à sua rede (ver documentação Coolify para a porta do dashboard).

## 2. Instalar o Coolify

Na VPS (como root ou com sudo), siga o instalador oficial:

- Documentação: [Coolify — Get Started](https://coolify.io/docs/get-started/introduction)

O script costuma instalar Docker e subir o painel Coolify. Guarde a URL e as credenciais que o instalador mostrar.

## 3. Registar o servidor no Coolify

1. No painel Coolify, adicione o **Server** (a própria VPS via SSH ou localhost, conforme o teu modelo de instalação).
2. Confirme que o servidor está “healthy” e que o **proxy** (Traefik) está ativo — o Coolify usa **80/443** para SSL (Let’s Encrypt).

### Importante: não uses `docker-compose.caddy.yml` no mesmo host

O ficheiro `docker-compose.caddy.yml` deste repositório sobe **Caddy** nas portas **80/443**, o que **conflita** com o proxy do Coolify.

- Em produção com Coolify: usa apenas a lógica de **reverse proxy do Coolify** (domínios nos serviços).
- Mantém o `docker-compose.yml` na raiz como base; **não** merges com `docker-compose.caddy.yml` neste cenário.

## 4. Novo recurso: Docker Compose

1. **Project** → **+ New Resource** → **Docker Compose**.
2. Liga o **repositório Git**, branch (ex. `main`) e define o caminho do compose: **`docker-compose.coolify.yml`** (raiz do repo).
   - Este ficheiro é igual ao `docker-compose.yml` mas **sem** `ports` no host — evita conflito com a **8080** (e outras) quando o Coolify/Traefik já usa essas portas na mesma VPS.
   - Se usares **`docker-compose.yml`**, cada **Reload Compose File** repõe as portas e o deploy volta a falhar com `port is already allocated` a menos que apagues manualmente os blocos `ports` no editor e **não** voltes a recarregar do Git sem os reaplicar.
3. Coolify **≥ v4.0.0-beta.411**: variáveis “mágicas” (`SERVICE_URL_*`, etc.) funcionam com compose via Git; em versões antigas, ver [notas Coolify](https://coolify.io/docs/knowledge-base/docker/compose).

## 5. Variáveis de ambiente (Coolify)

O Coolify deteta variáveis no formato `${NOME}` do compose. Configura no UI (valores de **produção**):

| Variável | Notas |
|----------|--------|
| `POSTGRES_USER` | Utilizador da BD (ex. `jjb`) |
| `POSTGRES_PASSWORD` | Palavra-passe forte |
| `POSTGRES_DB` | Nome da BD (ex. `jjb_db`) |
| `JWT_SECRET` | Mínimo **32 caracteres** (a API valida em produção) |
| `ENVIRONMENT` | `production` |
| `CORS_ORIGINS` | JSON com a origem do viewer, ex. `["https://app.seudominio.com"]` |
| `SEED_ON_STARTUP` | `false` em produção (recomendado) |
| `PGSSLMODE` | `disable` (Postgres interno na rede Docker sem TLS) |
| `API_BASE_URL` | URL **pública HTTPS** da API, ex. `https://api.seudominio.com` — **obrigatória** no Coolify: o viewer compila com `dart-define=API_BASE_URL` (`viewer/lib/config_web.dart`). Sem isto, o browser tenta `localhost:8001` ou `app.seudominio.com:8001` e o login falha. |
| `LOG_LEVEL` | `INFO` ou `WARNING` |
| `ENABLE_METRICS` | `true` se quiseres métricas |
| `FIREBASE_PROJECT_ID` | (Opcional) ID do projeto Firebase — necessário para **push** na API. |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | (Opcional) Caminho **dentro do contentor** ao JSON da service account; o compose Coolify usa por defeito `/app/secrets/firebase-service-account.json`. |
| `FIREBASE_SECRETS_HOST_PATH` | (Opcional) Pasta **no disco da VPS** montada em `/app/secrets` (só leitura). Por defeito `/srv/octogrip/secrets`. Coloca aí o ficheiro `firebase-service-account.json` (ver secção abaixo). |

O `DATABASE_URL` no compose já aponta para `postgres:5432` na rede interna — não é necessário alterar para o proxy público.

### Push (FCM) na VPS — passo a passo

1. **No Google Cloud / Firebase**  
   - [Firebase Console](https://console.firebase.google.com/) → Definições do projeto → **Contas de serviço** (ou [Google Cloud Console](https://console.cloud.google.com/) → IAM → Contas de serviço).  
   - Cria uma conta de serviço (ou usa uma existente) com permissões para enviar mensagens FCM (ex.: papel **Firebase Admin SDK Administrator** ou equivalente ao teu projeto).  
   - **Chaves** → **Adicionar chave** → **JSON** → descarrega o ficheiro (guarda-o em local seguro; não commits no Git).

2. **ID do projeto**  
   - No Firebase: Definições do projeto → **ID do projeto** — é o valor de `FIREBASE_PROJECT_ID` (ex.: `octogrip`).

3. **Na VPS (SSH)** — pasta só no servidor, nunca no repositório:

   ```bash
   sudo mkdir -p /srv/octogrip/secrets
   sudo nano /srv/octogrip/secrets/firebase-service-account.json
   # cola o conteúdo do JSON descarregado, grava e sai
   sudo chmod 600 /srv/octogrip/secrets/firebase-service-account.json
   ```

   Alternativa: copiar com `scp` a partir do teu PC, por exemplo:

   `scp .\firebase-adminsdk-xxxxx.json user@IP_DA_VPS:/srv/octogrip/secrets/firebase-service-account.json`

4. **No Coolify** (recurso Docker Compose desta app) → **Environment Variables** (ou equivalente ao teu painel):

   - `FIREBASE_PROJECT_ID` = o ID do passo 2.  
   - `FIREBASE_SERVICE_ACCOUNT_PATH` = `/app/secrets/firebase-service-account.json` (se o nome do ficheiro for outro, ajusta para coincidir com o ficheiro dentro de `/app/secrets` no contentor).  
   - Se usares outra pasta no host em vez de `/srv/octogrip/secrets`, define também `FIREBASE_SECRETS_HOST_PATH` com o caminho absoluto dessa pasta na VPS.

5. **Redeploy** da stack para a API voltar a subir com o volume montado e as variáveis aplicadas.

6. **Teste** — com utilizador gerente/professor autenticado, `POST /academies/{id}/push_notification` com título/corpo; se faltar configuração, a API responde **503** com mensagem explícita. Ver também `docs/PUSH_NOTIFICATIONS.md`.

Referência de segurança: `docs/CHECKLIST_DEPLOY.md`.

## 6. Domínios no Coolify (proxy → contentores)

Segundo a [documentação Coolify — Docker Compose](https://coolify.io/docs/knowledge-base/docker/compose):

- Serviço **viewer**: escuta na porta **80** no contentor → atribui domínio HTTPS, ex. `https://app.seudominio.com` (sem sufixo de porta no URL público).
- Serviço **api**: escuta na porta **8000** no contentor → ao configurar o domínio no Coolify, indica a porta **8000** na configuração do serviço (o UI do Coolify usa isso para rotear para o contentor; o utilizador acede sempre por 443 no domínio).

O **postgres** não deve ter domínio público. Com **`docker-compose.coolify.yml`** não há `ports` no host — só acesso interno entre serviços e via proxy do Coolify.

Se por algum motivo usares o `docker-compose.yml` no Coolify, remove manualmente os blocos `ports` dos três serviços no editor e **evita** “Reload Compose File” a partir do Git sem voltar a aplicar essa alteração (ou o erro **8080** volta).

Depois configura **domínios** no UI do Coolify para `viewer` (porta **80**) e `api` (porta **8000**).

## 7. Ordem e rebuild do viewer

1. Define primeiro os domínios finais (ou URLs estáveis) que vais usar.
2. Garante `API_BASE_URL=https://api.seudominio.com` **antes** do build do viewer — o Flutter embute esta URL em compile time.
3. Faz **Deploy**. Se mudares o domínio da API, é necessário **reconstruir** a imagem do serviço `viewer` (novo build com novo `API_BASE_URL`).

A API executa **migrations** no arranque (`app/main.py` → `run_migrations`).

## 8. Verificação pós-deploy

- `GET https://api.seudominio.com/health` → 200  
- `GET https://api.seudominio.com/health/db` → base ligada  
- Abre `https://app.seudominio.com` e testa login / fluxos críticos  

## 9. Alternativas (se preferires não usar um único compose)

- **PostgreSQL** como recurso “Database” gerido pelo Coolify e **API** como aplicação Docker (Dockerfile na raiz) — ajustas `DATABASE_URL` para o hostname interno que o Coolify indicar.
- **Viewer** como recurso separado (build a partir de `viewer/Dockerfile` com build arg `API_BASE_URL`).

O caminho **um Docker Compose** costuma ser o mais simples para manter `postgres`, `api` e `viewer` alinhados com o `docker-compose.yml` do repositório.

## 10. Resolução de problemas

### `Bind for 0.0.0.0:8080 failed: port is already allocated`

Significa que a porta **8080** no host da VPS já está ocupada (muito comum no mesmo servidor onde corre o Coolify). O `docker-compose.yml` do repositório mapeia o viewer para `8080:80` para desenvolvimento local; **no Coolify isso deve ser removido** (secção acima).

O mesmo tipo de erro pode aparecer com **8001** (API) ou **5432** (Postgres) se essas portas estiverem em uso.

**Correção:** no compose editável do recurso no Coolify, apaga os blocos `ports:` de `viewer`, `api` e (recomendado) `postgres`; volta a fazer **Deploy**; confirma domínios nos serviços `viewer` e `api`.

Na VPS podes confirmar o que usa a porta, por exemplo: `ss -tlnp | grep 8080` ou `docker ps` (coluna PORTS).

## Referências internas

- Compose local: `docker-compose.yml`  
- Compose Coolify (sem portas no host): `docker-compose.coolify.yml`  
- Caddy (não usar no mesmo host que Coolify): `docker-compose.caddy.yml`, `deploy/caddy/Caddyfile`  
- Checklist geral: `docs/CHECKLIST_DEPLOY.md`
