# Melhorias sugeridas — AppBaby (JJB)

Documento de referência para lembrar das funcionalidades e melhorias planejadas.  
Atualizado conforme o backlog e revisões de código.

---

## Prioridade alta

| Item | Descrição | Status |
|------|-----------|--------|
| **Autenticação (JWT/OAuth)** | Login com email + senha; JWT; rotas sensíveis usam `user_id` do token. Ver `docs/AUTH.md`. | Concluído |
| **CORS em produção** | Trocar `allow_origins=["*"]` por origens específicas via `ALLOWED_ORIGINS` no `.env`. | A fazer |
| **Testes backend (pytest)** | Criar `tests/` com fixtures de DB, testes de services e rotas principais. | Concluído |

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
| **Paginação** | Em listas grandes, adicionar `offset`/cursor e metadados (`total`, `next_cursor`). | Concluído |
| **CI/CD** | Pipeline (GitHub Actions ou similar): lint, testes, build Docker. | Concluído |
| **Health check no Docker** | Usar `healthcheck` no serviço `api` no `docker-compose` e `depends_on: condition: service_healthy`. | A fazer |
| **Cache HTTP** | Headers `Cache-Control` em rotas como `/lessons`, `/positions`, `/academies`. | A fazer |
| **Retry no app** | Retry com backoff em falhas temporárias (timeout, 503) no `ApiService`. | A fazer |

---

## Resumo por tema

- **Segurança:** Autenticação JWT, CORS, rate limiting, não expor detalhes em 500.
- **Testes:** pytest no backend (61 testes passando), testes de widget/screen no Flutter.
- **Código:** Documentar migrações, estado global no Flutter, paginação.
- **DevOps:** CI/CD (GitHub Actions com 3 jobs: test, lint, docker), health check no Docker.
- **Performance/UX:** Cache HTTP, retry no app.

---

---

## Detalhes das implementações concluídas

### Testes backend (P4)

- **61 testes** cobrindo rotas principais (health, auth, users, academies, positions, techniques, lessons, missions, executions)
- **Fixtures async** com PostgreSQL real (`jjb_db_test`) usando `pytest-asyncio` com event loop session-scoped
- **Test client** via `httpx.AsyncClient` com override de `get_db` dependency
- **Isolamento** entre testes usando UUIDs únicos (sem necessidade de TRUNCATE)
- **Arquivos:** `tests/conftest.py`, `tests/test_*.py` (8 arquivos), `requirements-test.txt`, `pyproject.toml`

### CI/CD (P4)

- **GitHub Actions** workflow (`.github/workflows/ci.yml`) com 3 jobs:
  - `test`: PostgreSQL 16 como service, instala deps, roda `pytest -v`
  - `lint`: Roda `ruff check` no código
  - `docker`: Build da imagem Docker (apenas em push para main/master)
- **Configuração:** PostgreSQL service com health check, variáveis de ambiente para testes

### Otimização de Performance (P5)

#### Backend
- **N+1 Queries corrigidas:** `reset_academy_missions` otimizado para buscar todos os usuários de uma vez em vez de queries individuais
- **Agregação SQL:** Uso de `func.sum()` em vez de carregar todos os registros na memória
- **6 índices compostos** adicionados nas tabelas principais para otimizar queries frequentes
- **Queries otimizadas:** `get_academy_ranking` removida query extra de nomes; `get_points_log` com projeção direta em vez de `selectinload` completo
- **Paginação:** Adicionada em `list_users` (offset/limit) e `get_points_log` (offset)

#### Frontend
- **ListView.builder:** Substituído `ListView` por `ListView.builder` em `library_screen.dart` e `academy_panel_screen.dart` para lazy loading
- **Debounce:** Adicionado debounce de 300ms em campos de busca para reduzir re-renderizações
- **Otimização de setState:** Agrupamento de múltiplos `setState` em `student_home_screen.dart`
- **Paginação:** Implementada paginação com botão "Carregar mais" em listas grandes

---

*Última atualização: P5 concluído - otimizações de performance implementadas.*
