# Plano de Auditoria de Código

## Análise Realizada

### Problemas Identificados

#### 1. Funções Muito Grandes e Complexas

**Funções com alta complexidade identificadas:**

- `create_execution` (execution_service.py:30-185) - ~155 linhas, múltiplos caminhos condicionais
- `confirm_execution` (execution_service.py:254-314) - ~60 linhas, lógica complexa de cálculo de pontos
- `get_points_log` (execution_service.py:356-465) - ~110 linhas, múltiplas queries e processamento
- `upsert_academy_week_missions` (mission_crud_service.py:171-276) - ~105 linhas, loops aninhados
- `get_academy_weekly_report` (academy_service.py:292-382) - ~90 linhas, múltiplas queries e merge de dados
- `compute_trophy_counts` (trophy_service.py:170-205) - duplicação de lógica com `_compute_counts_from_executions`

#### 2. Código Duplicado

- `compute_trophy_counts` e `_compute_counts_from_executions` têm lógica duplicada para contar execuções por faixa
- `get_academy_ranking` e `get_academy_weekly_report` têm lógica similar de merge de dados
- Cálculo de pontos em `confirm_execution` tem múltiplos caminhos condicionais que poderiam ser extraídos

#### 3. Tratamento de Erros

**Pontos positivos:**
- Uso consistente de exceções customizadas (`AppError`, `NotFoundError`, etc.)
- Try/except em pontos críticos (`ensure_weekly_missions_if_needed`, `update_academy`)

**Pontos a melhorar:**
- Algumas funções não têm tratamento de erro para operações de banco (rollback explícito)
- `get_points_log` não trata erros de queries auxiliares
- `upsert_academy_week_missions` tem múltiplos commits que podem falhar parcialmente

#### 4. Logs

**Pontos positivos:**
- Logging presente na maioria dos serviços
- Uso de `logger.info` para operações importantes
- Uso de `logger.exception` para erros

**Pontos a melhorar:**
- Algumas funções críticas não têm logs de entrada/saída
- Falta de logs em operações de merge/combinação de dados
- `trophy_service.py` não tem logs em funções principais

#### 5. Código Morto Potencial

- Verificar se todas as funções helper são utilizadas
- Verificar imports não utilizados
- Verificar funções de serviço não chamadas por rotas

## Correções Propostas

### Fase 1: Refatoração de Funções Grandes

#### 1.1 Refatorar `create_execution`

**Problema**: Função com ~155 linhas e múltiplos caminhos condicionais (technique_id, mission_id, lesson_id)

**Solução**: Extrair lógica em funções helper

#### 1.2 Refatorar `confirm_execution`

**Problema**: Lógica complexa de cálculo de base_points com múltiplos caminhos

**Solução**: Extrair cálculo de base_points em função separada

#### 1.3 Refatorar `get_points_log`

**Problema**: ~110 linhas com múltiplas queries e processamento

**Solução**: Extrair queries e processamento em funções helper

#### 1.4 Refatorar `upsert_academy_week_missions`

**Problema**: ~105 linhas com loops aninhados e múltiplos commits

**Solução**: Extrair lógica de criação/atualização por slot

#### 1.5 Refatorar `get_academy_weekly_report`

**Problema**: Lógica similar a `get_academy_ranking` com duplicação

**Solução**: Extrair função comum para merge de dados

### Fase 2: Eliminar Duplicação

#### 2.1 Consolidar Cálculo de Counts de Troféus

**Problema**: `compute_trophy_counts` duplica lógica de `_compute_counts_from_executions`

**Solução**: Fazer `compute_trophy_counts` usar `_compute_counts_from_executions`

#### 2.2 Extrair Lógica Comum de Rankings

**Problema**: `get_academy_ranking` e `get_academy_weekly_report` têm lógica similar

**Solução**: Criar função helper comum para merge

### Fase 3: Melhorar Tratamento de Erros

#### 3.1 Adicionar Rollback Explícito

**Arquivos**: Funções com múltiplos commits

**Solução**: Usar transações explícitas com try/except e rollback

#### 3.2 Tratar Erros em Queries Auxiliares

**Arquivo**: `execution_service.py` - `get_points_log`

**Solução**: Adicionar try/except para queries de técnicas

### Fase 4: Melhorar Logs

#### 4.1 Adicionar Logs de Entrada/Saída

**Arquivos**: Funções críticas sem logs

**Solução**: Adicionar logs no início e fim de funções críticas

#### 4.2 Adicionar Logs em Operações de Merge

**Arquivo**: `academy_service.py` - funções de ranking

**Solução**: Logar quantidade de dados processados

#### 4.3 Adicionar Logs em trophy_service

**Problema**: Funções principais sem logs

**Solução**: Adicionar logs em `compute_trophy_counts`, `compute_user_trophy_tier`, `list_user_trophies_with_earned`

### Fase 5: Identificar e Remover Código Morto

#### 5.1 Verificar Funções Não Utilizadas

**Ações**:
- Verificar se todas as funções helper são chamadas
- Verificar imports não utilizados
- Verificar funções de serviço não expostas em rotas

#### 5.2 Remover Imports Não Utilizados

**Ferramenta**: Usar `ruff check --select F401` para identificar imports não utilizados

#### 5.3 Verificar Funções Duplicadas

**Ações**:
- Verificar se há funções com nomes similares que fazem a mesma coisa
- Consolidar funções duplicadas

## Arquivos Prioritários para Refatoração

### Alta Prioridade (Funções Muito Grandes)

1. `app/services/execution_service.py`
   - `create_execution` (~155 linhas)
   - `get_points_log` (~110 linhas)
   - `confirm_execution` (~60 linhas, complexo)

2. `app/services/mission_crud_service.py`
   - `upsert_academy_week_missions` (~105 linhas)

3. `app/services/academy_service.py`
   - `get_academy_weekly_report` (~90 linhas)

### Média Prioridade (Duplicação e Complexidade)

4. `app/services/trophy_service.py`
   - Eliminar duplicação entre `compute_trophy_counts` e `_compute_counts_from_executions`

5. `app/services/academy_service.py`
   - Extrair lógica comum entre `get_academy_ranking` e `get_academy_weekly_report`

### Baixa Prioridade (Melhorias)

6. Adicionar logs em funções críticas
7. Melhorar tratamento de erros com rollback explícito
8. Remover código morto e imports não utilizados

## Métricas de Sucesso

- Reduzir funções > 100 linhas: 0 ocorrências
- Reduzir funções > 50 linhas: < 5 ocorrências
- Eliminar duplicação de código: 0 blocos duplicados > 10 linhas
- Cobertura de logs: 100% em funções críticas
- Tratamento de erros: 100% em operações de banco

## Testes Recomendados

1. Testar funções refatoradas mantêm comportamento original
2. Verificar que logs estão sendo gerados corretamente
3. Testar tratamento de erros em cenários de falha
4. Executar análise estática (ruff, mypy) para identificar problemas

## Checklist de Implementação

- [ ] Refatorar `create_execution` em funções menores
- [ ] Refatorar `confirm_execution` extraindo cálculo de pontos
- [ ] Refatorar `get_points_log` em funções helper
- [ ] Refatorar `upsert_academy_week_missions` extraindo lógica
- [ ] Refatorar `get_academy_weekly_report` extraindo função comum
- [ ] Eliminar duplicação em `compute_trophy_counts`
- [ ] Extrair lógica comum de rankings
- [ ] Adicionar rollback explícito em transações
- [ ] Adicionar logs em funções críticas
- [ ] Remover código morto e imports não utilizados
