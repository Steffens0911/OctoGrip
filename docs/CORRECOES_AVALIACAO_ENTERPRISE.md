# Correções Implementadas — Avaliação Enterprise

Este documento lista todas as correções implementadas com base nas avaliações enterprise realizadas.

---

## ✅ Correções da 1ª Avaliação

### 1. Isolamento de Academy (Segurança — Crítico)

**Problema**: Endpoints permitiam acesso cross-academy, violando isolamento multi-tenant.

**Correções**:

- **`mission_complete_service.py`**: Validação para garantir que não-admins só podem completar missões da própria academy.
- **`lesson_complete_service.py`**: Validação para garantir que não-admins só podem completar lições da própria academy.
- **`execution_service.py`**: Validação de isolamento em `_create_mission_execution`, `_create_lesson_execution` e `create_execution`.
- **`mission_usage_service.py`**: Validação em `sync_mission_usages` para garantir que cada `lesson_id` pertence à academy do usuário.

### 2. Autenticação Obrigatória em Endpoints de Missão

**Problema**: `GET /mission_today/week` aceitava query params sem auth obrigatória.

**Correção**: Substituído `get_current_user_optional` por `get_current_user` (auth obrigatória).

### 3. Full Table Scan no Fallback de Missão (Performance)

**Correção**: Adicionado filtro por `academy_id` e ordenação determinística.

### 4. Password Hashing Async (Performance)

**Correção**: `hash_password()` e `verify_password()` convertidas para async com `asyncio.to_thread()`.

### 5. Paginação em Endpoints sem Limite (Escalabilidade)

**Correção**: `offset`/`limit` em `list_lessons`, `list_pending_confirmations`, `list_my_executions`.

### 6. Índice Composto para Performance

**Correção**: Migration `031_add_execution_confirmed_at_index.sql` com índice composto.

---

## ✅ Correções da 2ª Avaliação (Reavaliação)

### 7. Padronização de Error Handling (Manutenibilidade — Alto Impacto)

**Problema**: Rotas levantavam `HTTPException` diretamente, acoplando lógica HTTP ao código de rota e impedindo reuso consistente de domain exceptions.

**Correção**:
- Criadas novas exceções de domínio: `AuthenticationError`, `ForbiddenError`, `MissionNotFoundError`, `ProfessorNotFoundError`, `ConflictError`.
- **Todas** as rotas migradas para usar domain exceptions (zero `HTTPException` em `app/`).
- `auth_deps.py` e `role_deps.py` também migrados para domain exceptions.
- Exception handler em `main.py` atualizado para adicionar `WWW-Authenticate` em respostas 401.
- Helper `get_user_or_raise()` adicionado ao `user_service.py` para eliminar padrão repetitivo.

**Arquivos modificados**: `app/routes/*.py`, `app/core/auth_deps.py`, `app/core/role_deps.py`, `app/core/exceptions.py`, `app/main.py`, `app/services/user_service.py`

### 8. Redução de Duplicação com Helpers (Manutenibilidade)

**Problema**: Padrão repetido de resolver `academy_id` em várias rotas.

**Correção**: 
- Função `_resolve_academy_id()` extraída nas rotas de techniques e positions.
- Imports inline (`from app.core.role_deps import verify_academy_access`) substituídos por imports no topo.

### 9. Cache In-Memory com TTL (Escalabilidade)

**Problema**: Endpoints read-heavy (técnicas, posições) consultavam o banco a cada request.

**Correção**:
- Criado módulo `app/core/cache.py` com `TTLCache`: cache in-memory com TTL, lock asyncio, eviction de expirados e por tamanho máximo.
- Instâncias `techniques_cache` e `positions_cache` com TTL de 120s.
- Invalidação automática do cache em operações de escrita (create, update, delete).
- Substituível por Redis sem alterar interface.

**Arquivos criados**: `app/core/cache.py`
**Arquivos modificados**: `app/services/technique_service.py`

### 10. UNION ALL para get_points_log (Performance — SQL)

**Problema**: `get_points_log` fazia 2 queries separadas e merge em Python, gerando overhead e paginação imprecisa.

**Correção**:
- Reescrito com `UNION ALL` em SQLAlchemy: execuções confirmadas + mission_usages combinados em uma única query SQL.
- Paginação e ordenação aplicadas no banco, eliminando `sort()` e `[:limit]` em Python.
- Lookups de nomes de técnicas e oponentes feitos em batch com `IN`.

**Arquivos modificados**: `app/services/execution_service.py`

### 11. Paginação em list_academies (Escalabilidade)

**Problema**: Endpoint de academias sem paginação para admin.

**Correção**: Adicionados parâmetros `offset` e `limit` no `GET /academies`.

**Arquivos modificados**: `app/routes/academies.py`

### 12. Cache-Control Diferenciado por Endpoint (Performance)

**Problema**: Header `Cache-Control: no-store` aplicado uniformemente, impedindo cache de respostas estáticas.

**Correção**: 
- Endpoints GET de `/techniques`, `/positions` e `/lessons` retornam `Cache-Control: private, max-age=60`.
- Demais endpoints mantêm `no-store, no-cache, must-revalidate`.

**Arquivos modificados**: `app/core/middleware.py`

### 13. Account Lockout (Segurança)

**Problema**: Sem proteção contra brute-force além do rate limiting global.

**Correção**:
- Mecanismo de lockout por e-mail: bloqueia por `ACCOUNT_LOCKOUT_MINUTES` (default: 15) após `ACCOUNT_LOCKOUT_ATTEMPTS` (default: 5) tentativas falhas.
- Configurável via variáveis de ambiente.
- Métrica Prometheus `security_events_total{event_type="account_locked"}`.
- Tentativas limpas automaticamente após login bem-sucedido.

**Arquivos modificados**: `app/routes/auth.py`, `app/config.py`

### 14. Remoção de Código Morto (Manutenibilidade)

**Problema**: Import inline de `HTTPException` em `lessons.py` e `from uuid import UUID` não utilizado em `mission.py`.

**Correção**: Imports limpos e código morto removido.

### 15. Coverage Threshold no CI (Qualidade)

**Problema**: Pipeline CI não exigia cobertura mínima de testes.

**Correção**: Adicionado `--cov-fail-under=60` ao pytest no CI.

**Arquivos modificados**: `.github/workflows/ci.yml`

### 16. Mass Assignment em Schemas Faltantes (Segurança)

**Problema**: `MissionUsageItem` e `MissionUsageSyncRequest` sem `extra="forbid"`.

**Correção**: `model_config = ConfigDict(extra="forbid")` adicionado.

**Arquivos modificados**: `app/schemas/mission_usage.py`

---

## 📊 Resumo Geral

| Categoria | Problemas Corrigidos | Status |
|-----------|---------------------|--------|
| **Segurança** | Isolamento de academy, auth obrigatória, account lockout, mass assignment | ✅ Completo |
| **Performance** | Full table scan, async password, UNION ALL, Cache-Control, índice composto | ✅ Completo |
| **Escalabilidade** | Paginação (5 endpoints), cache in-memory | ✅ Completo |
| **Manutenibilidade** | Error handling padronizado, helpers, código morto removido | ✅ Completo |
| **CI/CD** | Coverage threshold | ✅ Completo |

---

## 🔄 Próximos Passos Recomendados

1. **Redis para cache distribuído**: Migrar `TTLCache` para Redis em produção multi-instância.
2. **Rate Limiting distribuído**: Migrar `slowapi` para backend Redis.
3. **CSRF Validation**: Middleware para validar tokens CSRF em formulários.
4. **API Versioning**: Prefixo `/api/v1/` para versionamento.

---

**Data de implementação**: fevereiro de 2026  
**Baseado em**: `docs/AVALIACAO_ENTERPRISE.md`
