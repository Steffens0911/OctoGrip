# Referência da API — JJB

Documentação completa dos endpoints da API REST.

**Base URL:** `http://localhost:8000` (ou conforme configuração)  
**Documentação interativa:** `/docs` (Swagger)

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
14. [Exceções HTTP](#exceções-http)

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
  "academy_id": "uuid | null"
}
```

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
  "completed_at": "datetime"
}
```

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

**Resposta (201):**
```json
{
  "user_id": "uuid",
  "mission_id": "uuid",
  "completed_at": "datetime"
}
```

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

## Exceções HTTP

| Código | Exceção              | Quando                         |
|--------|----------------------|--------------------------------|
| 404    | NotFoundError        | Recurso não encontrado         |
| 409    | AlreadyCompletedError| Lição/missão já concluída      |
| 400    | AppError             | Erro genérico de validação     |

Mensagens em `detail` no JSON de resposta.
