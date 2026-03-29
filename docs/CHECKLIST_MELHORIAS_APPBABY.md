# Checklist de Melhorias — AppBaby

Checklist prático para execução por etapas das melhorias do AppBaby.

## Como usar

- Atualize o `Status` de cada item: `Nao iniciado`, `Em andamento`, `Concluido`, `Bloqueado`.
- Defina `Responsavel` e `Prazo` para cada melhoria antes de iniciar.
- Preencha `Evidencia` com links de PR, commit, print, teste ou documento.
- Revise o checklist no fechamento de cada sprint.

## Campos de controle

| Campo | Descricao |
|-------|-----------|
| Prioridade | Alta, Media, Estrutural |
| Status | Nao iniciado, Em andamento, Concluido, Bloqueado |
| Responsavel | Pessoa dona da execucao |
| Prazo | Data alvo (AAAA-MM-DD) |
| Evidencia | PR/commit/teste/documento |

---

## 1) Base solida (Prioridade alta)

| Item | Prioridade | Status | Responsavel | Prazo | Evidencia |
|------|------------|--------|-------------|-------|-----------|
| [x] Padronizar erros da API (formato unico + codigos por dominio) | Alta | Concluido |  |  | `app/main.py` |
| [x] Reforcar validacoes de negocio (soft delete, dependencias e mensagens claras) | Alta | Concluido |  |  | `app/services/mission_crud_service.py`, `app/services/lesson_service.py` |
| [ ] Ampliar testes de integracao (CRUD + auditoria + recuperacao) | Alta | Nao iniciado |  |  |  |
| [x] Implementar logs estruturados (`request_id`, usuario, rota, duracao, status) | Alta | Concluido |  |  | `app/core/middleware.py` |
| [x] Revisar seguranca de rotas admin (RBAC/perfis) | Alta | Concluido |  |  | `app/routes/users.py`, `app/routes/professors.py`, `app/routes/metrics.py` |
| [ ] Definir health checks completos (app, banco, dependencias) | Alta | Nao iniciado |  |  |  |

---

## 2) Experiencia do admin e produto (Prioridade media)

| Item | Prioridade | Status | Responsavel | Prazo | Evidencia |
|------|------------|--------|-------------|-------|-----------|
| [ ] Adicionar filtros, ordenacao e paginacao nas telas administrativas | Media | Nao iniciado |  |  |  |
| [ ] Criar busca global para licoes, missoes, tecnicas e trofeus | Media | Nao iniciado |  |  |  |
| [ ] Melhorar feedback visual (toast padrao, loading, estado vazio, erro amigavel) | Media | Nao iniciado |  |  |  |
| [ ] Refinar auditoria no viewer (filtro por usuario, acao e periodo) | Media | Nao iniciado |  |  |  |
| [ ] Criar onboarding rapido (tour + checklist de primeiros passos) | Media | Nao iniciado |  |  |  |
| [ ] Melhorar acessibilidade (contraste, foco teclado, labels) | Media | Nao iniciado |  |  |  |

---

## 3) Escala e operacao (Prioridade estrutural)

| Item | Prioridade | Status | Responsavel | Prazo | Evidencia |
|------|------------|--------|-------------|-------|-----------|
| [ ] Versionar API com prefixo `/v1` | Estrutural | Nao iniciado |  |  |  |
| [ ] Adicionar pipeline CI/CD (lint, testes, build, validacao de migration) | Estrutural | Nao iniciado |  |  |  |
| [ ] Criar ambiente de staging para homologacao | Estrutural | Nao iniciado |  |  |  |
| [ ] Implementar monitoramento (metricas, erros frontend, alertas) | Estrutural | Nao iniciado |  |  |  |
| [ ] Planejar cache para endpoints de leitura frequente | Estrutural | Nao iniciado |  |  |  |
| [ ] Formalizar backup/restore com testes periodicos | Estrutural | Nao iniciado |  |  |  |

---

## 4) Documentacao e governanca

| Item | Prioridade | Status | Responsavel | Prazo | Evidencia |
|------|------------|--------|-------------|-------|-----------|
| [ ] Documentar contrato da API (inputs, outputs, erros esperados) | Alta | Nao iniciado |  |  |  |
| [ ] Criar runbook de incidentes (diagnostico e recuperacao) | Media | Nao iniciado |  |  |  |
| [ ] Padronizar checklist de release (pre e pos deploy) | Media | Nao iniciado |  |  |  |
| [ ] Registrar decisoes tecnicas (ADR curto por mudanca relevante) | Media | Nao iniciado |  |  |  |

---

## Fechamento da sprint

| Pergunta | Resposta |
|----------|----------|
| O que foi concluido nesta sprint? |  |
| O que ficou bloqueado e por que? |  |
| Quais riscos permanecem para a proxima sprint? |  |
| Qual item de maior impacto para iniciar na proxima sprint? |  |
