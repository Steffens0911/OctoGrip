# Seção Academia

Documentação da API de **Academias** (recurso B2B: usuários vinculados, missões por academia, tema semanal e relatórios).

**Base URL:** `/academies` (prefixo da API conforme `router.py`).

---

## Modelo

| Campo                 | Tipo     | Obrigatório | Descrição |
|-----------------------|----------|-------------|-----------|
| `id`                  | UUID     | sim (PK)    | Identificador único |
| `name`                | string   | sim         | Nome da academia (até 255 caracteres) |
| `slug`                | string   | não         | Identificador amigável único (gerado a partir do nome se omitido) |
| `weekly_theme`        | string   | não         | Tema semanal (legado); preferir `weekly_technique_id` |
| `weekly_technique_id` | UUID     | não         | Técnica da **Missão 1** (seg–ter). Ao salvar, cria/atualiza missões da semana. |
| `weekly_technique_2_id` | UUID   | não         | Técnica da **Missão 2** (qua–qui). |
| `weekly_technique_3_id` | UUID   | não         | Técnica da **Missão 3** (sex–dom). |

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
  "weekly_technique_id": "uuid-tecnica-1",
  "weekly_technique_2_id": "uuid-tecnica-2",
  "weekly_technique_3_id": "uuid-tecnica-3",
  "weekly_theme": "Texto livre (legado)"
}
```

- `name`: opcional, 1–255 caracteres.
- `slug`: opcional, até 255 caracteres.
- `weekly_technique_id`: opcional, UUID da técnica **Missão 1** (seg–ter). Cria/atualiza missões da semana.
- `weekly_technique_2_id`: opcional, UUID da técnica **Missão 2** (qua–qui).
- `weekly_technique_3_id`: opcional, UUID da técnica **Missão 3** (sex–dom).
- `weekly_theme`: opcional, legado (texto livre).
- Se só `weekly_technique_id` estiver preenchido, missão aparece apenas no slot 1; os outros slots ficam vazios.

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

## Três missões semanais (A-03)

A academia pode definir **até 3 técnicas semanais** (slots):

| Slot | Coluna              | Período (por padrão) |
|------|---------------------|----------------------|
| Missão 1 | `weekly_technique_id`  | Seg–Ter |
| Missão 2 | `weekly_technique_2_id`| Qua–Qui |
| Missão 3 | `weekly_technique_3_id`| Sex–Dom |

- Se só **Missão 1** estiver preenchida, a técnica aparece **apenas no slot 1**; slots 2 e 3 ficam vazios.
- O endpoint `GET /mission_today/week` retorna as 3 entradas para o aluno; cada entrada tem `period_label` ("Missão 1", "Missão 2", "Missão 3") e `mission` (preenchida ou null).
- No **viewer**, o professor configura via 3 dropdowns no detalhe da academia; o aluno vê 3 cards na tela inicial.

---

## Missão do dia por academia (A-02)

A **missão do dia** pode ser definida **por academia**. Quando a academia escolhe uma missão, ela vale **só para os alunos daquela academia**; alunos de outras academias veem a missão da própria academia ou a missão global.

### Como funciona

1. **Cadastro de missão**  
   Em **Administração → Missões** (viewer) ou via API `POST /missions`, ao criar/editar uma missão é possível informar **Academia**:
   - **Academia** = uma academia específica → essa missão é a “missão do dia” **somente** para usuários vinculados a essa academia (desde que a data de hoje esteja entre início e fim da missão e o nível coincida).
   - **Academia** = Global (ou vazio) → a missão serve como **fallback** para quem não tem missão específica da academia (e para usuários sem academia).

2. **Resolução no backend**  
   O endpoint **GET /mission_today** (parâmetros: `level`, `user_id`, opcionalmente `academy_id`):
   - Se `user_id` for enviado, o backend usa o `academy_id` **do usuário** (quando o usuário está vinculado a uma academia).
   - Busca primeiro uma missão **ativa hoje** com `academy_id` = academia do aluno.
   - Se não houver missão da academia, usa missão **global** (`academy_id` nulo).
   - Assim, cada academia pode ter sua própria missão do dia; alterar a missão de uma academia **não** altera a missão das outras.

3. **Quem “escolhe” a missão da academia**  
   O professor ou administrador da academia define a missão ao **criar/editar uma Missão** com:
   - Lição desejada;
   - Data início e fim cobrindo o dia desejado;
   - Nível (ex.: beginner);
   - **Academia** = a academia em questão (não Global).

### Checklist para funcionar corretamente

| Item | Onde | Descrição |
|------|------|-----------|
| **Usuários vinculados à academia** | Administração → Usuários | Cada aluno deve ter o campo **Academia** preenchido com a academia correta. Só assim o backend usa a academia dele ao buscar a missão do dia. |
| **Missão com academia definida** | Administração → Missões | A missão que deve ser “do dia” para essa academia precisa ter **Academia** = essa academia (não Global), **Início** ≤ hoje, **Fim** ≥ hoje, e **Nível** compatível. |
| **Chamada com user_id** | Viewer (área do aluno) | A área do aluno envia o `user_id` ao chamar a API; o backend resolve o `academy_id` a partir do usuário. Nenhuma ação extra no app é necessária. |

### Resumo

- A missão do dia **pode ser escolhida por academia** (cadastrando uma Missão com essa academia).
- Quando a academia muda a missão, a mudança vale **apenas para os alunos daquela academia**; as outras academias continuam com a missão delas (ou global).
- Basta: **Missão com `academy_id` = academia** e **Usuários com `academy_id` = mesma academia**.

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
