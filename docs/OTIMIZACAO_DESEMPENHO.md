# Otimização de Desempenho — Octogrip

> Documenta o pacote de otimizações de performance aplicado para deixar o app
> "rápido e fluido, parecendo local". Cobre backend (FastAPI), frontend (Flutter
> web) e infraestrutura (nginx, Docker, Postgres).
>
> Data: junho/2026 · Branch: `main` · Sem mudanças arquiteturais (sem WebSockets,
> sem troca de gerenciamento de estado).

---

## 1. Contexto e objetivo

O app estava lento no boot e na navegação. A investigação (backend, frontend e
infra) apontou quatro causas principais:

- **Boot do Flutter em série** — a home esperava `refreshMe()` terminar antes de
  hidratar o snapshot e disparar os outros carregamentos.
- **Endpoints de boot pesados e sem cache** — `/me/training_stats` fazia 14
  queries sequenciais; `/trophies/me/home-summary`, 6 queries com lazy loads;
  `/auth/me`, 2 queries sempre.
- **Entrega ruim de assets** — nginx sem gzip e sem cache; `main.dart.js` de
  5,5 MB; `/media` sem `Cache-Control`.
- **Polling agressivo** — fotos a cada 4s, notificações a cada 30s, refetch
  completo a cada retorno ao primeiro plano.

---

## 2. Resumo dos ganhos

| Cenário | Antes | Depois | Ganho percebido |
|---|---|---|---|
| Navegar entre abas (cache quente) | spinner + rede | render instantâneo | ~85% |
| Voltar / reabrir o app | refetch total | cache + revalida ao fundo | ~70% |
| Recarregar página (browser) | re-baixa 5,5 MB | assets em cache + gzip | ~65% |
| Login → home pronta | boot em série | boot paralelo + cache | ~50% |
| Feed de fotos / mídia | re-baixa sempre | cache imutável | ~45% |
| Sob carga (vários alunos) | pool 12, I/O bloqueante | pool 72, I/O off-loop | ~40% |
| 1ª carga em aparelho novo | 5,5 MB no fio | 1,5 MB (gzip) | ~35% |

**Medições locais confirmadas:**

| Item | Antes | Depois |
|---|---|---|
| `main.dart.js` no fio | 5,5 MB | **1,5 MB** (gzip, −72%) |
| Fonte de ícones (`MaterialIcons`) | 1,6 MB | **32 KB** (tree-shake, −98%) |
| `/me/training_stats` | 14 queries | **4 queries** + cache 90s |
| `/trophies/me/home-summary` | 6 queries | **3 queries** + cache 120s |
| `/auth/me` | 2 queries | **1 query** (streak cacheado 6h) |

> Os percentuais por cenário são estimativas de engenharia; as medições de
> tamanho/queries são reais. O número exato de latência depende da rede e do VPS.

### 2.1 Medições reais de latência (stack no Docker)

Medido na stack rodando localmente, **de dentro da rede do Docker** (api →
`localhost:8000`) para eliminar o overhead de host→container do Docker Desktop no
Windows (WSL2/NAT) — overhead que **não existe em produção** (no VPS Linux o nginx
e a api ficam colocados). Usuário de teste: aluna com 34 execuções e 24 presenças;
buffers do Postgres aquecidos.

| Endpoint | Cache MISS (query completa) | Cache HIT | Ganho |
|---|---|---|---|
| `/me/training_stats` | 263 ms | **24 ms** | **11×** |
| `/trophies/me/home-summary` | 62 ms | **17 ms** | **4×** |
| `/auth/me` | 15 ms | 17 ms | ~1× ¹ |

¹ `/auth/me` já era rápido; o cache do streak não muda o tempo, mas **elimina uma
query** (`login_days LIMIT 400`) — alivia o banco no boot, quando todos os alunos
chamam ao mesmo tempo.

Com cache **totalmente frio** (buffers do Postgres também frios, só no 1º acesso
após restart), `/me/training_stats` mediu **1037 ms → 19 ms (53×)**.

**Provas coletadas no teste:**
- Cache populando: chave `app_cache:login_streak:<uid>:<dia>` criada após as chamadas.
- Índice 083 em uso: `EXPLAIN` mostra `Bitmap Index Scan on
  ix_technique_executions_user_confirmed_created`.
- Todos os endpoints retornaram HTTP 200 com token real.

> Como o TTL é curto (90s), na prática quase todo acesso de aluno pega cache
> quente — é o que faz a home "abrir na hora". Medições do **host Windows** dão
> piso de ~230 ms e picos de vários segundos por causa da rede do Docker Desktop;
> não refletem o servidor e foram descartadas.

---

## 3. Backend (FastAPI + SQLAlchemy + Redis)

### 3.1 `/me/training_stats` — 14 → 4 queries + cache
`app/routes/me_training_stats.py`

- Métricas do próprio aluno (workouts 30d, último check-in, posições 30d/total,
  vídeos 30d) viraram **scalar subqueries em uma única ida** ao banco.
- Médias top-10 e rankings da academia consolidados em **CTEs** com
  `count(...) FILTER (...)` e `row_number() OVER (...)`.
- Cache Redis `training_stats:{user_id}` (TTL 90s) via `app_cache`
  (`app/core/cache.py`). Helper em `app/services/training_stats_cache.py`.

> Semântica preservada (validada com comparação SQL antiga × nova, inclusive o
> caso de borda "aluno sem execuções → último lugar").

### 3.2 `/trophies/me/home-summary` — 6 → 3 queries + cache versionado
`app/services/trophy_service.py`

- Totais (automáticos + manuais) em uma query (scalar subqueries).
- `my_recent` e `academy_recent` via **`UNION ALL` com `ORDER BY`/`LIMIT` no
  banco** (antes buscava 3+3 e 10+10 e mesclava em Python).
- Cache com **prefixo versionado** `trophy_home:a:{academy_id}:` (TTL 120s).
  Uma conquista invalida a academia inteira com `bump_prefix_version` — sem
  `SCAN` no Redis.

### 3.3 `/auth/me` — streak cacheado
`app/services/login_streak_service.py`

- Cacheia apenas `login_streak_days` (`login_streak:{user_id}:{dia}`, TTL 6h). A
  chave inclui o dia no fuso do app, então a virada da meia-noite invalida
  sozinha. O objeto `user` **não** é cacheado (XP/graduação precisam estar
  frescos no boot).

### 3.4 Migration 083 — índice parcial
`migrations/083_technique_executions_perf_index.sql`

```sql
CREATE INDEX IF NOT EXISTS ix_technique_executions_user_confirmed_created
  ON technique_executions (user_id, created_at)
  WHERE status = 'confirmed';
```
Cobre as contagens/rankings de `training_stats` e a checagem de troféus.
Confirmado em uso via `EXPLAIN` (bitmap index scan).

### 3.5 Trabalho síncrono fora do event loop
- `app/routes/photos.py` — pipeline PIL do watermark via `asyncio.to_thread`.
- `app/routes/users.py` — `write_bytes` de avatar e foto facial via `to_thread`.

Antes esses pontos bloqueavam o worker inteiro durante o processamento.

### 3.6 Pool de conexões
`app/config.py` — `DB_POOL_SIZE=12`, `DB_MAX_OVERFLOW=6` (era 8/4). Com 4 workers
uvicorn: 4 × 18 = 72 conexões máx., com folga dentro de `max_connections=100`.

### 3.7 Cache-Control em `/media`
`app/core/middleware.py` (`SecurityHeadersMiddleware`) — antes forçava
`no-store` em toda mídia. Agora:
- `/media/photos/*` (nome único por post): `public, max-age=31536000, immutable`.
- Avatares/logos (reusam nome ao trocar): `max-age=300, stale-while-revalidate=600`
  + ETag do `StaticFiles`.

### Estratégia de invalidação dos caches (sempre **após** o commit)

| Chave | TTL | Invalidada por | Onde |
|---|---|---|---|
| `training_stats:{user_id}` | 90s | confirmação de execução, check-in, vídeo diário | `execution_service`, `attendance_service`, `training_video_service` |
| `trophy_home:a:{id}:` (versionado) | 120s | troféu auto/manual concedido ou revogado | `trophy_notification_service`, `manual_trophy_service` |
| `login_streak:{user_id}:{dia}` | 6h | login | `apply_login_streak_bonus` (grava o valor novo) |

---

## 4. Frontend (Flutter web — `viewer/lib`)

### 4.1 Boot paralelo da home
`viewer/lib/screens/student/student_home_screen.dart`

- Com usuário já em memória, o snapshot de disco pinta o header no **primeiro
  frame** e o `refreshMe()` entra no `Future.wait` junto dos outros loads (antes
  bloqueava tudo antes deles).
- Se academia/graduação mudar no refresh (raro), refaz os loads dependentes em
  modo silencioso.

### 4.2 Stale-while-revalidate no ApiService
`viewer/lib/services/api_service.dart`

- `_CacheEntry` ganhou `staleAtMs` (soft TTL) além de `expiresAtMs` (hard TTL,
  10 min). Dentro do soft: serve direto. Entre soft e hard: **serve o cache na
  hora e revalida em background**.
- Deduplicação de GETs simultâneos por chave (generaliza o padrão antigo que só
  existia para training videos). É o principal responsável pela sensação de
  "parecendo local" ao navegar.

### 4.3 Polling de fotos com backoff
`viewer/lib/features/photos/presentation/state/photos_feed_notifier.dart`

- Intervalo 4s → 8s → 16s (teto), reset quando um status muda, desiste após ~20
  tentativas sem progresso (pull-to-refresh religa). O provider autodispose já
  cancela o timer ao sair da tela.

### 4.4 Notificações, resume e "Atuar como"
`viewer/lib/main.dart`

- Badge de notificações: 30s → **60s**, pausado em `paused`/`hidden`, refeito no
  `resumed`.
- Resume não refaz fetch cego — com o SWR vira "render do cache + revalida".
- `getUsersAll` cacheado por 60s (o diálogo "Atuar como" refazia 1+ requests
  paginados a cada abertura). Cache limpo em `invalidateCache`.

---

## 5. Infraestrutura e build

### 5.1 nginx do viewer
`viewer/nginx.default.conf`

- `gzip on` + `gzip_types` (js, css, json, **wasm**, ttf…). `main.dart.js`:
  5,5 MB → **1,5 MB** no fio.
- Assets sem hash (`assets/`, `canvaskit/`, `icons/`): `Cache-Control
  public, max-age=86400` + ETag. **Sem `immutable`** (o service worker versiona).
- `index.html`, `flutter_bootstrap.js` etc. continuam `no-cache` (não servir
  bundle velho após deploy).

### 5.2 `--tree-shake-icons`
`.github/workflows/build-viewer.yml` e `README.md` — flag explícita no
`flutter build web`. Reduz a fonte de ícones de 1,6 MB para 32 KB.

### 5.3 Postgres
`docker-compose.yml` e `docker-compose.coolify.yml` — `random_page_cost=1.1`
(SSD: o planner passa a preferir index scans). Aplica no restart do container.

### 5.4 Contexto de build Docker
`.dockerignore` — exclui `.claude/` (~340 MB de transcripts/plans que inflavam o
`transferring context` da imagem da api) e `secrets/` + `*.sql` (segurança: nunca
assar segredos na imagem).

> Nota: a imagem da api inclui TensorFlow + DeepFace (~572 MB) para reconhecimento
> facial. Quando o cache do buildkit é evictado, o rebuild reinstala tudo e pode
> levar ~30 min; com cache quente, ~4 min. Não confundir lentidão de build com
> problema de runtime.

---

## 6. Como testar localmente

**Stack completa (como produção):**
```powershell
cd viewer
flutter.bat build web --release --tree-shake-icons --dart-define-from-file=tool/dart_define_web.json
cd ..
docker compose up -d --build viewer api
docker compose up -d postgres   # recria com random_page_cost=1.1
```
Abrir `http://localhost:8080` e medir no DevTools → Network.

**Verificações rápidas (curl):**
```bash
# gzip ativo no bundle (deve mostrar Content-Encoding: gzip e ~1.5MB)
curl -sI -H "Accept-Encoding: gzip" http://localhost:8080/main.dart.js | grep -i content-encoding

# cache dos assets
curl -sI http://localhost:8080/canvaskit/canvaskit.wasm | grep -i cache-control

# index nunca cacheado
curl -sI http://localhost:8080/index.html | grep -i cache-control

# health da api
curl -s http://localhost:8001/health
```

---

## 7. Checklist de deploy (produção)

1. `git push` → CI do viewer builda com as flags novas (aguardar ✅).
2. Aplicar a **migration 083** no banco de produção.
3. **Redeploy da API** no Coolify (pega pool, caches Redis e headers de mídia).
4. **Restart do container do Postgres** no Coolify (para o `random_page_cost`).

> Build do Flutter, `docker build` e deploy no Coolify são sempre etapas manuais
> — não automatizar.

---

## 8. Verificação realizada

- ✅ **289 testes** do backend passando (`pytest`); `flutter analyze` sem
  erros/warnings novos.
- ✅ Semântica antiga × nova de `training_stats` e `trophy_home` comparada em SQL
  no banco real — idêntica, incluindo casos de borda.
- ✅ Índice 083 aplicado e confirmado em uso via `EXPLAIN`.
- ✅ Smoke test dos endpoints otimizados ponta a ponta com dados reais.
- ✅ gzip (−72%), tree-shake (−98%) e cache de assets confirmados via curl no
  container do viewer.
