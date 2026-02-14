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
13. [Exceções HTTP](#exceções-http)

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
  "before_training_percent": 0.0
}
```

---

## Exceções HTTP

| Código | Exceção              | Quando                         |
|--------|----------------------|--------------------------------|
| 404    | NotFoundError        | Recurso não encontrado         |
| 409    | AlreadyCompletedError| Lição/missão já concluída      |
| 400    | AppError             | Erro genérico de validação     |

Mensagens em `detail` no JSON de resposta.
