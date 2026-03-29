# Referência da API — JJB

Documentação completa dos endpoints da API REST.

**Base URL:** `http://localhost:8000` (ou conforme configuração)  
**Documentação interativa:** `/docs` (Swagger)

### CORS (Flutter Web e preflight)

O frontend em **outra origem** (ex.: `http://localhost:55767` → API `http://localhost:8000`) dispara pedidos **OPTIONS** (preflight). O `CORSMiddleware` deve responder **200** com os cabeçalhos `Access-Control-*` corretos.

- **`allow_headers=["*"]`** com **`allow_credentials=False`**: o Starlette espelha no preflight os headers pedidos pelo browser (`Authorization`, `X-Impersonate-User`, etc.), evitando **400 Disallowed CORS headers** que bloqueava CRUD no Flutter Web. Não combinar `allow_headers=["*"]` com `allow_credentials=True` (restrição do Starlette).
- **`CorsFallbackMiddleware`** (camada ASGI externa): se a resposta ainda não tiver `Access-Control-Allow-Origin` e o `Origin` for permitido pelo mesmo regex que o `CORSMiddleware`, o header é acrescentado — reduz falsos positivos de CORS no browser em respostas longas ou atípicas (ex.: `POST /admin/backup/restore`).
- **Produção**: definir **`CORS_ORIGINS`** com as origens do frontend (ver `app/config.py`).

Impersonação admin usa o header `X-Impersonate-User` nos pedidos reais.

---

## Índice

1. [Health](#health)
2. [Academias](#academias)
3. [Usuários](#usuários)
4. [Lições](#lições)
5. [Técnicas e Posições](#técnicas-e-posições)
6. [Missões](#missões)
7. [Missão do dia / Semana](#missão-do-dia--semana)
8. [Conclusão de lição](#conclusão-de-lição)
9. [Conclusão de missão](#conclusão-de-missão)
10. [Histórico de missões](#histórico-de-missões)
11. [Feedback de treino](#feedback-de-treino)
12. [Métricas](#métricas)
13. [Relatórios](#relatórios)
14. [Admin — backup da base](#admin--backup-da-base)
15. [Exceções HTTP](#exceções-http)

---

## Health

| Método | Endpoint   | Descrição                        |
|--------|------------|----------------------------------|
| GET    | /health    | Health check simples             |
| GET    | /health/db | Health check + conexão Postgres  |

---

## Academias

Base: `/academies`. Detalhes em [ACADEMIAS.md](ACADEMIAS.md).

| Método | Endpoint                    | Descrição                                      |
|--------|-----------------------------|------------------------------------------------|
| GET    | /academies                  | Lista academias                                |
| POST   | /academies                  | Cria academia                                  |
| GET    | /academies/{id}             | Detalhe da academia                            |
| PATCH  | /academies/{id}             | Atualiza academia (incl. 3 técnicas semanais)  |
| DELETE | /academies/{id}             | Exclui academia                                |
| GET    | /academies/{id}/ranking     | Ranking interno (period_days, limit)           |
| GET    | /academies/{id}/difficulties| Posições mais reportadas como difíceis         |
| GET    | /academies/{id}/report/weekly | Relatório semanal (year, week opcionais)    |
| GET    | /academies/{id}/report/weekly/csv | Relatório semanal em CSV                 |

**PATCH /academies/{id}** — body opcional:
```json
{
  "name": "string",
  "slug": "string",
  "weekly_theme": "string",
  "weekly_technique_id": "uuid | null",
  "weekly_technique_2_id": "uuid | null",
  "weekly_technique_3_id": "uuid | null"
}
```

---

## Usuários

Base: `/users`.

| Método | Endpoint      | Descrição           |
|--------|---------------|---------------------|
| GET    | /users        | Lista usuários      |
| POST   | /users        | Cria usuário        |
| GET    | /users/{id}   | Detalhe do usuário  |
| PATCH  | /users/{id}   | Atualiza usuário    |
| DELETE | /users/{id}   | Exclui usuário      |
| GET    | /users/{id}/points_log | Histórico de pontuação do usuário |

### GET /users/{id}/points_log

Retorna o histórico de pontuação unificado (execuções confirmadas, conclusões de missão e vídeo diário).

**Query params:**
| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| limit     | int  | 100    | Limite de itens (1..500 recomendado) |
| offset    | int  | 0      | Paginação por deslocamento |

**Resposta (200):**
```json
{
  "user_id": "uuid",
  "entries": [
    {
      "date": "2026-03-23T10:15:00Z",
      "points": 20,
      "source": "execution",
      "description": "Execução confirmada: raspagem",
      "impact_level": "medium",
      "quality_score": 0.63
    }
  ]
}
```

**Contrato recomendado para gamificação saudável:**
- `impact_level` (opcional): `low | medium | high`
- `quality_score` (opcional): `0.0 .. 1.0`

Quando os campos opcionais não forem informados, o frontend deve manter fallback por `source` e `points`.

**Mapeamento sugerido no backend (v1):**
- `execution`: usar `points_awarded` e contexto da confirmação.
  - `high`: `>= 30`, `medium`: `>= 15`, `low`: `< 15`
- `mission`: `impact_level = medium` por padrão (ou calcular por dificuldade/multiplier).
- `training_video`: `impact_level = low` com foco em consistência.
- `quality_score`:
  - `execution`: normalizar `points_awarded` para 0..1 (cap em 50 pontos).
  - `mission`: base em `multiplier / 50`.
  - `training_video`: base em `points_per_day / 50`.

**Observações de compatibilidade:**
- Adição de `impact_level` e `quality_score` é backward compatible.
- Evitar remover/renomear `date`, `points`, `source`, `description`.

---

## Lições

Base: `/lessons`.

| Método | Endpoint      | Descrição           |
|--------|---------------|---------------------|
| GET    | /lessons      | Lista lições        |
| POST   | /lessons      | Cria lição          |
| GET    | /lessons/{id} | Detalhe da lição    |
| PATCH  | /lessons/{id} | Atualiza lição      |
| DELETE | /lessons/{id} | Exclui lição        |

---

## Técnicas e Posições

| Base   | Endpoints | Descrição                         |
|--------|-----------|-----------------------------------|
| /techniques | GET, POST, GET/{id}, PATCH, DELETE | CRUD de técnicas |
| /positions  | GET, POST, GET/{id}, PATCH, DELETE | CRUD de posições |

---

## Missões

Base: `/missions`. CRUD para painel do professor.

**Pontuação:** `multiplier` da missão (e `points_per_day` dos vídeos de treino) fica na faixa **10–50**. Ao concluir uma missão (`POST /mission_complete`), os pontos creditados ao aluno são **iguais ao `multiplier` da missão** (persistido em `mission_usages.points_awarded`). Ao concluir uma lição pela biblioteca (`POST /lesson_complete`), credita-se o mínimo da faixa (10), em `lesson_progress.points_awarded`. O total em `GET /users/{id}/points` inclui execuções confirmadas (missão), `mission_usages`, `lesson_progress`, vídeos diários e `points_adjustment`. Em `GET /mission_today` e `GET /mission_today/week`, o `multiplier` devolvido segue o da missão; sem missão real, o fallback exibe **10**.

| Método | Endpoint      | Descrição              |
|--------|---------------|------------------------|
| GET    | /missions     | Lista (academy_id?, limit?) |
| POST   | /missions     | Cria missão            |
| GET    | /missions/{id}| Detalhe da missão      |
| PATCH  | /missions/{id}| Edita missão           |
| DELETE | /missions/{id}| Exclui missão          |
| GET    | /missions/panel | Painel web HTML para criar missão em 10s |

**POST /missions** — body:
```json
{
  "technique_id": "uuid",
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "level": "beginner | intermediate",
  "theme": "string | null",
  "academy_id": "uuid | null",
  "multiplier": 10
}
```

- `multiplier`: opcional; default **10**; deve estar entre **10** e **50** (pontos ao concluir a missão).

---

## Missão do dia / Semana

Base: `/mission_today`.

### GET /mission_today

Retorna a missão do dia para o aluno.

**Query params:**
| Parâmetro       | Tipo   | Padrão   | Descrição                                |
|-----------------|--------|----------|------------------------------------------|
| level           | string | beginner | beginner \| intermediate                 |
| user_id         | UUID   | —        | ID do usuário (resolve academy_id)       |
| academy_id      | UUID   | —        | Academia (override)                      |
| review_after_days | int  | 7        | Dias para priorizar revisão              |

**Resposta (200):**
```json
{
  "mission_id": "uuid | null",
  "technique_id": "uuid",
  "lesson_id": "uuid | null",
  "mission_title": "string",
  "lesson_title": "string",
  "description": "string",
  "video_url": "string",
  "position_name": "string",
  "technique_name": "string",
  "objective": "string | null",
  "estimated_duration_seconds": "int | null",
  "weekly_theme": "string | null",
  "is_review": false,
  "already_completed": false
}
```

- `already_completed`: `true` se o usuário já concluiu esta missão (usa `mission_id` ou `lesson_id`).

### GET /mission_today/week

Retorna as **3 missões semanais** (Missão 1, 2, 3).

**Query params:** `level`, `user_id`, `academy_id` (mesmos que acima).

**Resposta (200):**
```json
{
  "entries": [
    {
      "period_label": "Missão 1",
      "mission": { "mission_id": "...", "lesson_title": "...", ... } | null
    },
    {
      "period_label": "Missão 2",
      "mission": null
    },
    {
      "period_label": "Missão 3",
      "mission": null
    }
  ]
}
```

Se só a técnica 1 estiver configurada na academia, `mission` preenchida apenas em `entries[0]`.

---

## Conclusão de lição

Base: `/lesson_complete`.

### GET /lesson_complete/status

Verifica se a lição já foi concluída pelo usuário (para exibir botão desabilitado).

**Query params:** `user_id`, `lesson_id` (UUIDs).

**Resposta (200):**
```json
{ "completed": true }
```

### POST /lesson_complete

Registra conclusão da lição. **409** se já concluída.

**Body:**
```json
{
  "user_id": "uuid",
  "lesson_id": "uuid"
}
```

**Resposta (201):**
```json
{
  "lesson_id": "uuid",
  "user_id": "uuid",
  "completed_at": "datetime",
  "points_awarded": 10
}
```

- **`points_awarded`:** pontos creditados nesta conclusão (valor fixo mínimo da gamificação, alinhado a `MIN_REWARD_POINTS` no servidor) e incluídos no total do utilizador.

---

## Conclusão de missão

Base: `/mission_complete`.

### POST /mission_complete

Registra conclusão da missão. **409** se já concluída.

**Body:**
```json
{
  "user_id": "uuid",
  "mission_id": "uuid",
  "usage_type": "before_training | after_training"
}
```

- `usage_type`: default `after_training`; opcional.
- **Pontos:** o saldo do usuário aumenta em **`mission.multiplier`** (valor entre 10 e 50), gravado em `mission_usages.points_awarded`.

**Resposta (201):**
```json
{
  "user_id": "uuid",
  "mission_id": "uuid",
  "completed_at": "datetime",
  "points_awarded": 10
}
```

- **`points_awarded`:** igual ao valor gravado em `mission_usages.points_awarded` (multiplicador da missão limitado à faixa 10–50).

---

## Histórico de missões

Base: `/mission_usages`.

### GET /mission_usages/history

Lista missões concluídas pelo usuário.

**Query params:** `user_id` (obrigatório), `limit` (default 500).

**Resposta (200):**
```json
{
  "missions": [
    {
      "mission_id": "uuid",
      "lesson_title": "string",
      "technique_name": "string",
      "completed_at": "datetime",
      "usage_type": "before_training | after_training"
    }
  ]
}
```

### POST /mission_usages/sync

Sync de usos locais do app para o backend (PB-01). Ver schema `MissionUsageSyncRequest`.

---

## Feedback de treino

Base: `/training_feedback`.

### POST /training_feedback

Registra dificuldade em uma posição.

**Body:**
```json
{
  "user_id": "uuid",
  "position_id": "uuid",
  "observation": "string | null"
}
```

---

## Métricas

Base: `/metrics`.

### GET /metrics/usage

Métricas de uso (conclusões de lição e missão).

**Resposta (200):**
```json
{
  "total_completions": 0,
  "completions_last_7_days": 0,
  "unique_users_completed": 0,
  "before_training_count": 0,
  "after_training_count": 0,
  "before_training_percent": 0.0
}
```

---

## Relatórios

Base: `/reports`.

### GET /reports/engagement

Relatório de **engajamento por período**: porcentagem de alunos ativos na semana e no mês.

- **Aluno ativo** = usuário com `role = "aluno"` que fez **pelo menos 1 login** (`last_login_at`) no período.
- **Semana** = janela móvel dos últimos 7 dias em relação a `reference_date` (incluindo o dia).
- **Mês** = do 1º dia do mês até `reference_date`.

**Query params:**

| Parâmetro      | Tipo | Obrigatório | Descrição                                                                 |
|----------------|------|------------|---------------------------------------------------------------------------|
| reference_date | date | sim        | Data de referência (YYYY-MM-DD).                                         |
| academy_id     | UUID | não        | Se informado, limita à academia; se omitido, considera todas (visão global). |

**Resposta (200):**
```json
{
  "academy_id": "uuid-or-null",
  "weekly": {
    "start_date": "2026-02-20",
    "end_date": "2026-02-26",
    "total_students": 120,
    "active_students": 45,
    "active_rate": 37.5
  },
  "monthly": {
    "start_date": "2026-02-01",
    "end_date": "2026-02-26",
    "total_students": 120,
    "active_students": 80,
    "active_rate": 66.7
  }
}
```

### GET /reports/active_students

Relatório **detalhado de alunos ativos** em uma janela móvel de 7 dias.

- Usa a mesma definição de **aluno ativo** acima (login em até 7 dias).
- Sempre considera a janela `[reference_date - 6, reference_date]`.

**Query params:**

| Parâmetro      | Tipo | Obrigatório | Descrição                                                                 |
|----------------|------|------------|---------------------------------------------------------------------------|
| reference_date | date | sim        | Data de referência (YYYY-MM-DD).                                         |
| academy_id     | UUID | não        | Se informado, limita à academia; se omitido, considera todas (visão global). |

**Resposta (200):**
```json
{
  "academy_id": "uuid-or-null",
  "start_date": "2026-02-20",
  "end_date": "2026-02-26",
  "total_students": 120,
  "active_students": 45,
  "active_rate": 37.5,
  "students": [
    {
      "id": "uuid",
      "name": "Aluno 1",
      "email": "aluno1@jjb.com",
      "graduation": "white",
      "academy_id": "uuid",
      "academy_name": "Red Lions",
      "last_login_at": "2026-02-25T19:13:45.123456+00:00"
    }
  ]
}
```

### GET /reports/active_students/csv

Mesma informação de `/reports/active_students`, porém exportada em **CSV**, para uso em Excel/Sheets.

- Content-Type: `text/csv`
- Cabeçalho:

```text
id,name,email,graduation,academy_id,academy_name,last_login_at
```

---

## Admin — backup da base

### GET /admin/backup/database

- **Autenticação:** Bearer JWT obrigatório.
- **Autorização:** apenas role `administrador`.
- **Impersonação:** este endpoint deve ser chamado **sem** o header `X-Impersonate-User` (o usuário efetivo no token deve ser admin). Caso contrário a API devolve **403**.
- **Resposta (200):** corpo em **SQL plain** (dump PostgreSQL via `pg_dump`), `Content-Type: application/sql`, `Content-Disposition: attachment` com nome sugerido `jjb_backup_<UTC>.sql`.
- **Conteúdo:** banco de dados **completo** (todas as academias). **Não** inclui arquivos do volume `app_media` (logos, imagens).
- **Rate limit:** por defeito **3 pedidos/hora** por IP (`BACKUP_DOWNLOAD_RATE_LIMIT` em `app/config.py`; nos testes usa-se limite mais folgada).
- **Erros:**
  - **503** se `pg_dump`/`psql` falhar (ex.: inexistente no PATH, **versão major diferente do servidor** Postgres, ou falha de conexão). No Docker Compose, a imagem da API usa `postgresql-client-16` alinhado ao serviço `postgres:16` e define `PGSSLMODE=disable` por defeito para o cliente libpq (sobrescreva com `PGSSLMODE` no ambiente se usar TLS obrigatório).
- **Segurança:** o arquivo contém dados sensíveis (senhas em hash, e-mails, etc.); tratar como secreto.

**Restaurar só o SQL (exemplo, fora do app):**

```bash
psql -h HOST -U USER -d DBNAME -f jjb_backup_YYYYMMDD_HHMM.sql
```

### GET /admin/backup/archive

- Mesma autenticação, autorização, impersonação e rate limit que `GET /admin/backup/database`.
- **Resposta (200):** arquivo **ZIP**, `Content-Type: application/zip`, nome sugerido `jjb_backup_<UTC>.zip`.
- **Conteúdo do ZIP:**
  - `database.sql` — mesmo dump que o endpoint só-SQL.
  - `media/` — cópia recursiva de `app_media` (ex.: `academy_logos/`, `academy_schedules/`).

### POST /admin/backup/restore

- **Autenticação / autorização / impersonação:** iguais aos GET acima (sem `X-Impersonate-User`).
- **Body:** `multipart/form-data`, campo **`file`**: arquivo `.zip` produzido por `GET /admin/backup/archive` (ou com a mesma estrutura: `database.sql` na raiz).
- **Comportamento (destrutivo):**
  1. Extrai o ZIP com proteção contra path traversal.
  2. **Fecha os pools SQLAlchemy** (sync + async) deste processo **antes** do `psql`, para não manter sessões abertas que **bloqueiam** `DROP SCHEMA public CASCADE` (sem isto, o reset pode atingir timeout à espera de locks).
  3. Gera um script SQL temporário: `DROP SCHEMA public CASCADE`, `CREATE SCHEMA public`, `ALTER/GRANT` básicos do schema, seguido do conteúdo de `database.sql` (cópia em stream). Executa **um único** `psql -f` com `ON_ERROR_STOP=1`. **Não** usa `pg_terminate_backend` no script — terminava ligações do pool asyncpg ainda ligadas ao pedido e causava `InterfaceError` no rollback ao fechar a sessão. Antes do `psql`, a API chama `dispose()` nos engines SQLAlchemy; pings `SELECT 1` com retry (`BACKUP_PSQL_CONNECT_RETRIES`, …). Timeout: `BACKUP_PSQL_RESTORE_TIMEOUT_SEC` (default 7200s).
  4. Se existir pasta `media/` no ZIP **com pelo menos um arquivo**, substitui o conteúdo atual de `app_media` (remove entradas de primeiro nível e copia as do ZIP). Se não houver `media/` ou estiver vazia de arquivos, **não altera** `app_media`.
- **Resposta (200):** JSON `{ "ok": true, "restored_media": true | false }`. Após sucesso, a API **volta a descartar os pools**, valida `SELECT 1` no engine async e executa um passo defensivo para garantir `public` + `search_path` consistente.
- **Erros:** **400** (ZIP inválido ou estrutura incorreta), **413** (tamanho acima de `BACKUP_RESTORE_MAX_MB`, default 512), **422** (nome do arquivo não termina em `.zip`), **503** (`psql` indisponível ou falha na restauração / cópia de mídia), **507** (falha ao gravar o upload temporário, ex.: disco cheio).
- **Rate limit:** o endpoint **não** usa slowapi (upload multipart longo + limiter causava 500 opaco no browser); proteção por **tamanho máximo** (`BACKUP_RESTORE_MAX_MB`) e **só administrador**.
- **Nota:** durante a restauração outras requisições podem falhar; preferir janela de manutenção. Em caso de erro no restore, a API tenta auto-reparar `public/search_path` antes de responder 503, para evitar loop de reinício no startup.

---

## Exceções HTTP

| Código | Exceção              | Quando                         |
|--------|----------------------|--------------------------------|
| 404    | NotFoundError        | Recurso não encontrado         |
| 409    | AlreadyCompletedError| Lição/missão já concluída      |
| 400    | AppError             | Erro genérico de validação     |
| 422    | RequestValidationError | Payload/parametros inválidos |
| 413    | AppError             | Upload de restauração acima do limite (`BACKUP_RESTORE_MAX_MB`) |
| 429    | RateLimitExceeded    | Limite de requisições excedido |
| 503    | AppError             | Serviço indisponível (ex.: backup quando `pg_dump` falha) |
| 500    | Exception            | Falha interna não tratada       |

As respostas de erro seguem formato padronizado e mantêm compatibilidade com `detail`:

```json
{
  "detail": "Mensagem amigavel ou lista de erros",
  "error": {
    "code": "VALIDATION_ERROR",
    "type": "RequestValidationError",
    "message": "Dados de entrada inválidos.",
    "status_code": 422
  },
  "request_id": "uuid-ou-header-x-request-id",
  "path": "/rota/chamada",
  "timestamp": "2026-03-23T12:00:00.000000+00:00"
}
```
