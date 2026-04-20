# Desfazer alterações e recuperação (administrador global)

Este documento alinha **três camadas** de recuperação: restauração na aplicação, cópia SQL e infraestrutura de base de dados.

## 1. Restaurar na aplicação (auditoria)

**Quando usar:** alteração recente em entidade que gera entrada no feed **Admin → Auditoria e recuperação**, com histórico `CREATE` / `UPDATE` / `DELETE` / `RESTORE`.

- **Restaurar versão anterior:** escolher um log `UPDATE` ou `DELETE` e aplicar o `old_data` (snapshot) ao registo actual.
- **Reactivar após soft-delete:** registo com `deleted_at` preenchido — restaurar sem `audit_log_id` limpa `deleted_at`.

**Limitações:**

- Entidades com **eliminação física em cascata** (por exemplo utilizador) **não** voltam só com esta ferramenta; use cópia SQL ou PITR (abaixo).
- Operações de **execuções / pontos** podem usar acções administrativas dedicadas (reverter confirmação, etc.) descritas na API, além dos snapshots quando aplicável.

## 2. Cópia SQL (dump completo)

**Quando usar:** corrupção ampla, migração falhada, ou qualquer cenário sem linha de auditoria útil.

- No viewer: **Admin → Backup do banco de dados** (descarrega dump PostgreSQL).
- Manter cópias **fora** do servidor da app (object storage, outro host).
- **Checklist:** definir frequência (ex. diária em produção); pelo menos uma vez por trimestre **testar** `pg_restore` ou `psql` num ambiente isolado.

## 3. PITR / snapshots do Postgres (opcional, infra)

**Quando usar:** recuperar o estado da base a um **instante** (ex. “antes das 14h”).

- Configura-se no **hospedeiro** (Coolify, RDS, VM): WAL archiving, snapshots de volume ou backup contínuo.
- Não faz parte do código do OctoGrip; documente no runbook da vossa infra.

## 4. Eliminação de utilizador (`delete_user`)

A API remove o utilizador e dados associados em **cascata**. Isto é **irreversível** sem restaurar a partir de uma **cópia SQL ou PITR** feita antes da eliminação.

- A UI de admin pode exigir **confirmação explícita** (texto a digitar) antes de chamar o delete.
- Antes de eliminar contas importantes, fazer **dump** ou snapshot.

## Resumo rápido

| Situação | Caminho |
|----------|---------|
| Erro num cadastro com histórico na auditoria | Restore in-app |
| Execução confirmada por engano | `POST /admin/executions/{id}/revert_confirmation` (admin global) |
| Conclusão de missão / usage errado | `POST /admin/mission_usages/{id}/void` (admin global) |
| Perda ampla ou delete irreversível | Dump SQL ou PITR |

## Endpoints administrativos (compensação)

- **`POST /admin/executions/{execution_id}/revert_confirmation`** — só `administrador`; volta `status` para `pending_confirmation`, limpa pontos da confirmação e recalcula o nível do executor.
- **`POST /admin/mission_usages/{usage_id}/void`** — só `administrador`; apaga a linha `mission_usages` e recalcula o nível do utilizador.

Na app Flutter: **Admin → Auditoria e recuperação** inclui campos para estes dois pedidos.
