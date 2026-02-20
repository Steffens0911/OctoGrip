# Autenticação JWT — AppBaby

A API usa **JWT (JSON Web Token)** para autenticar o usuário. O cliente envia o token no header `Authorization: Bearer <token>`.

---

## Login

**POST** `/auth/login`

Body (JSON):
```json
{
  "email": "aluno@jjb.com",
  "password": "senha123"
}
```

Resposta (200):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

Use o `access_token` em todas as requisições que exigem autenticação.

---

## Usuário logado

**GET** `/auth/me` — requer `Authorization: Bearer <token>`

Retorna o usuário autenticado (id, email, name, graduation, academy_id, points_adjustment).

---

## Rotas que exigem autenticação

- **POST** `/mission_complete` — body: `mission_id`, `usage_type` (user do token)
- **GET** `/lesson_complete/status?lesson_id=...` — user do token
- **POST** `/lesson_complete` — body: `lesson_id` (user do token)
- **POST** `/executions` — body sem `user_id` (executor = user do token)
- **GET** `/executions/pending_confirmations/count` e **GET** `/executions/pending_confirmations` — adversário = user do token
- **POST** `/executions/{id}/confirm` e **POST** `/executions/{id}/reject` — quem confirma/recusa = user do token
- **GET** `/executions/my_executions` — executor = user do token
- **POST** `/mission_usages/sync` — body: `usages` (user do token)
- **GET** `/mission_usages/history` — user do token
- **POST** `/training_feedback` — body: `position_id`, `observation?` (user do token)

---

## Rotas com autenticação opcional

- **GET** `/mission_today` e **GET** `/mission_today/week` — se enviar `Authorization: Bearer <token>`, o `user_id` usado para personalização (already_completed, revisão, etc.) é o do token; senão pode passar `user_id` na query (retrocompatibilidade).

---

## Variáveis de ambiente

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `JWT_SECRET` | Chave para assinar o token. **Altere em produção.** | `altere-em-producao-use-um-secret-forte` |
| `JWT_ALGORITHM` | Algoritmo do JWT | `HS256` |
| `JWT_EXPIRE_MINUTES` | Tempo de vida do token em minutos | `10080` (7 dias) |

---

## Seed e primeiro login

Após rodar o seed (`docker compose exec api python -m app.scripts.seed`), o usuário **aluno@jjb.com** tem senha **senha123** e pode fazer login.

Para definir senha em usuários já existentes (sem senha), use o endpoint de criação com senha ao criar novos usuários; para usuários antigos, é necessário atualizar `password_hash` no banco (ex.: script ou endpoint administrativo futuro).
