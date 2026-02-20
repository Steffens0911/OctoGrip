# Melhorias sugeridas — AppBaby (JJB)

Documento de referência para lembrar das funcionalidades e melhorias planejadas.  
Atualizado conforme o backlog e revisões de código.

---

## Prioridade alta

| Item | Descrição | Status |
|------|-----------|--------|
| **Autenticação (JWT/OAuth)** | Login com email + senha; JWT; rotas sensíveis usam `user_id` do token. Ver `docs/AUTH.md`. | Concluído |
| **CORS em produção** | Trocar `allow_origins=["*"]` por origens específicas via `ALLOWED_ORIGINS` no `.env`. | A fazer |
| **Testes backend (pytest)** | Criar `tests/` com fixtures de DB, testes de services e rotas principais. | A fazer |

---

## Prioridade média

| Item | Descrição | Status |
|------|-----------|--------|
| **Viewer: login e token** | Tela de login (email/senha), armazenar JWT e enviar `Authorization: Bearer <token>` nas chamadas autenticadas. | Concluído |
| **Testes Flutter** | Atualizar `widget_test.dart` para testar o app real (ex.: StudentHomeScreen, loading, erro). | A fazer |
| **Documentar migrações** | Manter `docs/MIGRATIONS.md` atualizado (ex.: 024–027). | A fazer |
| **Gerenciamento de estado (Riverpod)** | Reduzir `setState` e “refresh triggers”; usar Riverpod ou Provider para usuário e dados compartilhados. | A fazer |
| **Tratamento de erros 500** | Em produção não expor `str(exc)`; retornar mensagem genérica e registrar traceback em log. | A fazer |

---

## Prioridade baixa

| Item | Descrição | Status |
|------|-----------|--------|
| **Rate limiting** | Adicionar limite de requisições por IP/usuário (ex.: slowapi) em rotas sensíveis. | A fazer |
| **Paginação** | Em listas grandes, adicionar `offset`/cursor e metadados (`total`, `next_cursor`). | A fazer |
| **CI/CD** | Pipeline (GitHub Actions ou similar): lint, testes, build Docker. | A fazer |
| **Health check no Docker** | Usar `healthcheck` no serviço `api` no `docker-compose` e `depends_on: condition: service_healthy`. | A fazer |
| **Cache HTTP** | Headers `Cache-Control` em rotas como `/lessons`, `/positions`, `/academies`. | A fazer |
| **Retry no app** | Retry com backoff em falhas temporárias (timeout, 503) no `ApiService`. | A fazer |

---

## Resumo por tema

- **Segurança:** Autenticação JWT, CORS, rate limiting, não expor detalhes em 500.
- **Testes:** pytest no backend, testes de widget/screen no Flutter.
- **Código:** Documentar migrações, estado global no Flutter, paginação.
- **DevOps:** CI/CD, health check no Docker.
- **Performance/UX:** Cache HTTP, retry no app.

---

*Última atualização: conforme revisão de melhorias.*
