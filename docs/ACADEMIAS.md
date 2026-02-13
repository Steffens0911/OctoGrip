# Seção Academia

Documentação da API de **Academias** (recurso B2B: usuários vinculados, missões por academia, tema semanal e relatórios).

**Base URL:** `/academies` (prefixo da API conforme `router.py`).

---

## Modelo

| Campo          | Tipo     | Obrigatório | Descrição |
|----------------|----------|-------------|-----------|
| `id`           | UUID     | sim (PK)    | Identificador único |
| `name`         | string   | sim         | Nome da academia (até 255 caracteres) |
| `slug`         | string   | não         | Identificador amigável único (gerado a partir do nome se omitido) |
| `weekly_theme` | string   | não         | Tema semanal definido pelo professor (A-03), até 128 caracteres |

---

## CRUD — Operações principais

### Create (Criar)

| Método | Endpoint        | Descrição |
|--------|-----------------|-----------|
| **POST** | `POST /academies` | Cria uma nova academia. |

**Body (JSON):**

```json
{
  "name": "Academia do Centro",
  "slug": "academia-centro"
}
```

- `name`: obrigatório, 1–255 caracteres.
- `slug`: opcional; se vazio ou omitido, é gerado a partir do nome (lowercase, caracteres alfanuméricos e hífens).

**Resposta:** `201 Created` + corpo `AcademyRead` (id, name, slug, weekly_theme).

---

### Read (Ler)

| Método | Endpoint              | Descrição |
|--------|------------------------|-----------|
| **GET**  | `GET /academies`         | Lista todas as academias (ordenadas por nome). |
| **GET**  | `GET /academies/{academy_id}` | Retorna uma academia por ID. |

- Lista: resposta é um array de `AcademyRead`.
- Por ID: resposta é um único `AcademyRead`; `404` se não existir.

---

### Update (Atualizar)

| Método  | Endpoint                | Descrição |
|---------|-------------------------|-----------|
| **PATCH** | `PATCH /academies/{academy_id}` | Atualiza academia (campos enviados são opcionais). |

**Body (JSON) — todos os campos opcionais:**

```json
{
  "name": "Academia do Centro - Sede",
  "slug": "academia-centro-sede",
  "weekly_theme": "Guarda e passagem"
}
```

- `name`: opcional, 1–255 caracteres.
- `slug`: opcional, até 255 caracteres.
- `weekly_theme`: opcional, até 128 caracteres (A-03: tema semanal do professor).

**Resposta:** `200 OK` + corpo `AcademyRead`; `404` se a academia não existir.

---

### Delete (Excluir)

| Método   | Endpoint                 | Descrição |
|----------|--------------------------|-----------|
| **DELETE** | `DELETE /academies/{academy_id}` | Remove a academia. |

**Resposta:** `204 No Content` em sucesso; `404` se a academia não existir.

---

## Endpoints complementares (relatórios e ranking)

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| **GET** | `GET /academies/{academy_id}/ranking` | Ranking interno (missões concluídas). Parâmetros: `period_days` (default 30), `limit` (default 50). |
| **GET** | `GET /academies/{academy_id}/difficulties` | Posições mais reportadas como difíceis (T-02). Parâmetro: `limit` (default 50). |
| **GET** | `GET /academies/{academy_id}/report/weekly` | Relatório semanal (JSON). Parâmetros opcionais: `year`, `week` (ISO). |
| **GET** | `GET /academies/{academy_id}/report/weekly/csv` | Relatório semanal em CSV. Mesmos parâmetros `year`, `week`. |

---

## Resumo rápido — CRUD Academia

| Ação   | Método  | Endpoint                    |
|--------|---------|-----------------------------|
| Criar  | POST    | `/academies`                |
| Listar | GET     | `/academies`                |
| Buscar | GET     | `/academies/{academy_id}`   |
| Atualizar | PATCH | `/academies/{academy_id}`   |
| Excluir | DELETE | `/academies/{academy_id}`   |

Documentação interativa: **Swagger** em `/docs` (tag **academies**).
