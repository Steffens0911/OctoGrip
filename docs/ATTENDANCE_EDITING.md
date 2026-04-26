# Edição de presenças (professor / gerente / admin)

Professores e gestores podem **corrigir** presenças em qualquer sessão (**ativa ou encerrada**), sem limite de tempo: adicionar aluno manualmente (sem QR) ou remover um registo.

## Escopo

- **Professor / `gerente_academia`**: vê todas as sessões da **mesma academia** (`GET /attendance/sessions`); pode filtrar só sessões criadas por si (`mine=true`).
- **`administrador`**: vê sessões de todas as academias.
- Apenas utilizadores com **escrita** (`require_write_access`: admin, gerente, professor) usam os endpoints de edição.

## REST

### Listar sessões

`GET /attendance/sessions`

| Query | Descrição |
|--------|-----------|
| `status` | `active` ou `closed` (opcional) |
| `mine` | `true` / `false` — só sessões criadas pelo utilizador |
| `date_from`, `date_to` | ISO 8601 — filtra por `starts_at` |
| `limit` | 1–200 (default 50) |
| `offset` | default 0 |

Resposta: array de objetos como `AttendanceSessionRead` (inclui `present_count`).

### Detalhe e lista de presentes (já existentes)

- `GET /attendance/sessions/{session_id}` — metadados + `present_count`
- `GET /attendance/sessions/{session_id}/records` — lista paginada de registos

### Adicionar presença manual

`POST /attendance/sessions/{session_id}/records`

```json
{ "user_id": "<uuid do aluno>" }
```

- O alvo tem de ser **`role` = aluno** e da **mesma academia** da sessão.
- **Idempotente**: se já existir presença `(session_id, user_id)`, devolve o registo existente com **201** (sem duplicar linha na BD).
- `method` no registo: `"manual"`.
- Emite evento WebSocket `checkin` (igual ao scan QR) **apenas** quando foi criado um registo novo.

### Remover presença

`DELETE /attendance/records/{record_id}`

- Resposta **204** sem corpo.
- **Hard delete** (não há soft delete em `attendance_records`).
- Após apagar, o servidor emite WebSocket `record_removed` (ver abaixo).

### Encerrar sessão (inalterado)

`POST /attendance/sessions/{session_id}/close`

## Estatísticas de frequência (`/stats`)

Leitura agregada para a tela **Frequência** (professor/gestor) e **Minha frequência** (aluno). As rotas `/stats/sessions` e `/stats/students` requerem `require_write_access`; `/stats/students/{id}` e **`/stats/me`** usam `get_current_user` (o próprio utilizador vê os seus dados).

### `GET /attendance/stats/sessions`

| Query | Descrição |
|--------|-----------|
| `professor_id` | Opcional. Default = utilizador autenticado. Admin pode consultar outro professor. Professor só pode consultar a si. Gerente: o `professor_id` tem de pertencer à mesma academia. |
| `from`, `to` | ISO 8601 em `starts_at`. Se ambos omitidos: últimos **30 dias** até agora. |
| `limit` | 1–500 (default 200). |

Resposta: `AttendanceSessionStatRead[]` — por sessão: `id`, `title`, `starts_at`, `ends_at`, `status`, `present_count` (sem % por sessão).

- **Admin**: todas as sessões do professor no intervalo (sem filtro de academia).
- **Professor / gerente**: só sessões da **sua** academia.

### `GET /attendance/stats/students`

| Query | Descrição |
|--------|-----------|
| `academy_id` | Opcional para admin com academia vinculada; professor/gerente usam sempre a própria (não podem pedir outra). |
| `from`, `to` | Igual acima. |

Resposta: `AttendanceStudentStatRead[]` — por aluno (`role=aluno`): `present_count`, `total_sessions` (sessões da academia no período), `attendance_rate` (0..1 = `present_count / total_sessions`), `last_seen_at`.

### `GET /attendance/stats/students/{student_id}`

| Query | Descrição |
|--------|-----------|
| `academy_id` | Opcional; default = academia do aluno. |
| `from`, `to` | Igual. |
| `records_limit` | 1–1000 (default 500). |

Resposta: `AttendanceStudentDetailRead` — resumo igual ao da lista + `records[]` (`AttendanceRecordWithSessionRead`: sessão + data de check-in + método), ordenado por `checked_in_at` descendente.

### `GET /attendance/stats/me`

Frequência do **utilizador autenticado** na academia do seu perfil (`user.academy_id`). Qualquer role com academia vinculada pode consultar; **404** se não houver `academy_id`.

| Query | Descrição |
|--------|-----------|
| `from`, `to` | ISO 8601 em `starts_at` da sessão. Se omitidos: últimos **30 dias** até agora. |
| `limit` | Tamanho da página do histórico (1–100, default **30**). |
| `offset` | Paginação do histórico (default 0). |

Resposta: `AttendanceMyStatsRead`

- **`total_sessions`**, **`total_checkins`**, **`percentage`** (0..1): no intervalo `from`–`to` (`percentage = total_checkins / total_sessions`).
- **`lifetime_total_sessions`**, **`lifetime_total_checkins`**, **`lifetime_percentage`**: todas as sessões da academia e todas as presenças do utilizador na academia (sem filtro de datas).
- **`last_seen_at`**: última presença registada (global na academia).
- **`bucket`**: `week` ou `month` — escolha automática: se `(to - from).days <= 60` usa **semana** (trunc ISO em `starts_at`), senão **mês**.
- **`checkins_by_period[]`**: buckets consecutivos no intervalo com `period_start`, `period_end`, `label` (ex. `2026-W17` ou `2026-04`), `present_count` (zeros preenchidos onde não houve presença).
- **`history[]`**: mesma forma que `AttendanceRecordWithSessionRead`, ordenado por `checked_in_at` descendente; **`history_total`**, **`history_limit`**, **`history_offset`**.

## WebSocket (tempo real)

Canal existente: `WS .../attendance/sessions/{session_id}/ws?token=<JWT>`.

### Evento `checkin` (já documentado)

Emitido em **novo** registo (QR ou manual).

### Evento `record_removed`

Emitido após `DELETE /attendance/records/{record_id}`:

```json
{
  "type": "record_removed",
  "session_id": "<uuid>",
  "record_id": "<uuid>",
  "user_id": "<uuid>",
  "present_count": 11
}
```

O cliente Flutter (`AttendanceLiveService`) deve atualizar a lista local e o contador `present_count`.

## App Flutter

- **Histórico**: `AttendanceHistoryScreen` → `AttendanceSessionDetailScreen`.
- **Frequência**: `AttendanceFrequencyScreen` (abas Minhas sessões / Alunos) → `AttendanceStudentDetailScreen`.
- **Minha frequência (aluno)**: `AttendanceMyStatsScreen` — card na home do aluno; `fl_chart` no separador por período.
- **Chamada ao vivo (QR)**: `AttendanceSessionScreen` — botões **Adicionar aluno** e remover por linha; mesmo WebSocket.
- **Widget partilhado**: `viewer/lib/widgets/attendance_add_student_dialog.dart`.

## cURL (exemplos)

```bash
# Listar (substitua TOKEN e BASE)
curl -s -H "Authorization: Bearer TOKEN" \
  "BASE/attendance/sessions?limit=20&mine=false"

curl -s -H "Authorization: Bearer TOKEN" -H "Content-Type: application/json" \
  -d '{"user_id":"ALUNO_UUID"}' \
  -X POST "BASE/attendance/sessions/SESSAO_UUID/records"

curl -s -H "Authorization: Bearer TOKEN" \
  -X DELETE "BASE/attendance/records/RECORD_UUID"

# Estatísticas (frequência)
curl -s -H "Authorization: Bearer TOKEN" \
  "BASE/attendance/stats/sessions?from=2026-01-01T00:00:00Z&to=2026-01-31T23:59:59Z"

curl -s -H "Authorization: Bearer TOKEN" \
  "BASE/attendance/stats/students?academy_id=ACADEMY_UUID&from=2026-01-01T00:00:00Z&to=2026-01-31T23:59:59Z"

curl -s -H "Authorization: Bearer TOKEN" \
  "BASE/attendance/stats/students/STUDENT_UUID?from=2026-01-01T00:00:00Z&to=2026-01-31T23:59:59Z"

curl -s -H "Authorization: Bearer TOKEN" \
  "BASE/attendance/stats/me?from=2026-01-01T00:00:00Z&to=2026-01-31T23:59:59Z&limit=30&offset=0"
```
