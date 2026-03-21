# Plano de Auditoria do Banco de Dados

## Objetivo
Auditar o banco de dados do AppBaby focando em:
1. Índices corretos
2. Relacionamentos bem definidos
3. Campos sensíveis protegidos
4. Migrações consistentes

---

## 1. Índices

### ✅ Índices Existentes (Bem Implementados)
- **User**: `email` (unique), `graduation`, `role`, `academy_id`
- **Academy**: `name`, `slug` (unique), `weekly_technique_id`, `weekly_technique_2_id`, `weekly_technique_3_id`, `visible_lesson_id`
- **Mission**: `technique_id`, `lesson_id`, `slot_index`, `start_date`, `end_date`, `level`, `academy_id`
  - Índice composto: `(academy_id, level, slot_index, is_active)`
- **MissionUsage**: `user_id`, `mission_id`, `lesson_id`
  - Índices compostos: `(user_id, mission_id)`, `(user_id, completed_at)`
- **TechniqueExecution**: `user_id`, `mission_id`, `lesson_id`, `technique_id`, `opponent_id`, `status`
  - Índices compostos: `(user_id, mission_id, status)`, `(opponent_id, status)`
- **LessonProgress**: 
  - Índice composto: `(user_id, completed_at)`
  - Constraint único: `(user_id, lesson_id)`
- **Lesson**: `academy_id`, `title`, `slug`, `technique_id`
- **Technique**: `academy_id`, `name`, `slug`, `description`, `video_url`, `base_points`
- **Position**: `academy_id`, `name`, `slug`
- **Professor**: `name`, `email` (unique), `academy_id`
- **Trophy**: `academy_id`, `technique_id`, `name`
- **CollectiveGoal**: `academy_id`, `technique_id`

### ⚠️ Índices Faltando ou Potenciais Melhorias

#### 1.1. TrainingFeedback
**Problema**: `user_id` e `position_id` não têm índices individuais.
**Impacto**: Queries filtrando por `user_id` ou `position_id` podem ser lentas.
**Solução**: Adicionar índices em `user_id` e `position_id`.

#### 1.2. LessonProgress
**Problema**: `lesson_id` não tem índice individual (só está no unique constraint).
**Impacto**: Queries filtrando por `lesson_id` podem ser lentas.
**Solução**: Adicionar índice em `lesson_id` (ou verificar se o unique constraint já cria índice).

#### 1.3. TechniqueExecution
**Problema**: `confirmed_by` não tem índice.
**Impacto**: Queries filtrando por quem confirmou podem ser lentas.
**Solução**: Adicionar índice em `confirmed_by` se houver queries frequentes por este campo.

#### 1.4. MissionUsage
**Problema**: `usage_type` não tem índice.
**Impacto**: Queries filtrando por `usage_type` (before_training/after_training) podem ser lentas.
**Solução**: Adicionar índice em `usage_type` se houver queries frequentes.

#### 1.5. TechniqueExecution
**Problema**: `usage_type` não tem índice.
**Impacto**: Queries filtrando por `usage_type` podem ser lentas.
**Solução**: Adicionar índice em `usage_type` se houver queries frequentes.

---

## 2. Relacionamentos (Foreign Keys e Cascades)

### ✅ Relacionamentos Bem Definidos

#### 2.1. User → Academy
- **FK**: `academy_id` → `academies.id`
- **Cascade**: `ondelete="SET NULL"` ✅ Correto (usuário não é deletado se academia for deletada)

#### 2.2. Academy → Techniques (weekly_technique_id, weekly_technique_2_id, weekly_technique_3_id)
- **FK**: `techniques.id`
- **Cascade**: `ondelete="SET NULL"` ✅ Correto (academia não perde referência se técnica for deletada)
- **Nota**: Usa `use_alter=True` para resolver dependência circular ✅

#### 2.3. Academy → Lesson (visible_lesson_id)
- **FK**: `lessons.id`
- **Cascade**: `ondelete="SET NULL"` ✅ Correto

#### 2.4. Mission → Technique
- **FK**: `techniques.id`
- **Cascade**: `ondelete="RESTRICT"` ✅ Correto (não permite deletar técnica se houver missões)

#### 2.5. Mission → Lesson
- **FK**: `lessons.id`
- **Cascade**: `ondelete="SET NULL"` ✅ Correto

#### 2.6. Mission → Academy
- **FK**: `academies.id`
- **Cascade**: `ondelete="CASCADE"` ✅ Correto (missões da academia são deletadas)

#### 2.7. MissionUsage → User
- **FK**: `users.id`
- **Cascade**: `ondelete="CASCADE"` ✅ Correto (histórico do usuário é deletado)

#### 2.8. MissionUsage → Mission
- **FK**: `missions.id`
- **Cascade**: `ondelete="SET NULL"` ✅ Correto (mantém histórico mesmo se missão for deletada)

#### 2.9. MissionUsage → Lesson
- **FK**: `lessons.id`
- **Cascade**: `ondelete="CASCADE"` ⚠️ **Revisar**: Se lesson for deletada, histórico de uso é perdido. Pode ser intencional.

#### 2.10. TechniqueExecution → User (user_id, opponent_id, confirmed_by)
- **FK**: `users.id`
- **Cascade**: `ondelete="CASCADE"` (user_id, opponent_id) ✅ Correto
- **Cascade**: `ondelete="SET NULL"` (confirmed_by) ✅ Correto (mantém execução mesmo se confirmador for deletado)

#### 2.11. TechniqueExecution → Mission, Lesson, Technique
- **FK**: `missions.id`, `lessons.id`, `techniques.id`
- **Cascade**: `ondelete="CASCADE"` ⚠️ **Revisar**: Se mission/lesson/technique for deletada, execuções são perdidas. Pode ser intencional.

#### 2.12. LessonProgress → User, Lesson
- **FK**: `users.id`, `lessons.id`
- **Cascade**: `ondelete="CASCADE"` ✅ Correto (progresso é deletado com usuário ou lição)

#### 2.13. TrainingFeedback → User, Position
- **FK**: `users.id`, `positions.id`
- **Cascade**: `ondelete="CASCADE"` ✅ Correto

#### 2.14. Technique → Academy
- **FK**: `academies.id` → `ondelete="CASCADE"` ✅ Correto

#### 2.15. Lesson → Academy, Technique
- **FK**: `academies.id` → `ondelete="SET NULL"` ✅ Correto
- **FK**: `techniques.id` → `ondelete="RESTRICT"` ✅ Correto

#### 2.16. Position → Academy
- **FK**: `academies.id`
- **Cascade**: `ondelete="CASCADE"` ✅ Correto

#### 2.17. Professor → Academy
- **FK**: `academies.id`
- **Cascade**: `ondelete="SET NULL"` ✅ Correto

#### 2.18. Trophy → Academy, Technique
- **FK**: `academies.id`, `techniques.id`
- **Cascade**: `ondelete="CASCADE"` ✅ Correto

#### 2.19. CollectiveGoal → Academy, Technique
- **FK**: `academies.id`, `techniques.id`
- **Cascade**: `ondelete="CASCADE"` ✅ Correto

### ⚠️ Relacionamentos que Precisam Revisão

#### 2.1. MissionUsage.lesson_id → CASCADE
**Situação**: Se uma lição for deletada, todo o histórico de uso relacionado é perdido.
**Análise**: 
- Há operações de delete em `lesson_service.py` que podem deletar lições
- O comportamento atual com CASCADE pode ser intencional para limpeza de dados
- **Decisão**: Manter como está por enquanto. Se houver necessidade de preservar histórico, considerar mudar para `SET NULL` no futuro.

#### 2.2. TechniqueExecution → Mission/Lesson/Technique → CASCADE
**Situação**: Se mission/lesson/technique for deletada, execuções são perdidas.
**Análise**:
- Há operações de delete em `mission_crud_service.py` e `technique_service.py`
- O comportamento atual com CASCADE pode ser intencional para limpeza de dados
- **Decisão**: Manter como está por enquanto. Se houver necessidade de preservar histórico de execuções, considerar mudar para `SET NULL` no futuro.

---

## 3. Campos Sensíveis Protegidos

### ✅ Campos Sensíveis Bem Protegidos

#### 3.1. User.password_hash
- **Proteção**: ✅ Não está incluído em `UserRead` schema
- **Armazenamento**: Hash pbkdf2_sha256 (não bcrypt, conforme comentário incorreto no modelo)
- **Validação**: Mínimo 12 caracteres, máximo 128 caracteres
- **Ação**: Corrigir comentário no modelo de "bcrypt" para "pbkdf2_sha256"

### ⚠️ Campos que Precisam Verificação

#### 3.1. Email em Professor
- **Verificação**: Email está em `Professor` mas não há schema de leitura específico. Verificar se não está sendo exposto indevidamente.

#### 3.2. Tokens JWT
- **Verificação**: Tokens não são armazenados no banco (correto), apenas em memória/cookies.

---

## 4. Migrações Consistentes

### ✅ Migrações Bem Estruturadas

- **Sistema de tracking**: Tabela `_migrations` para rastrear migrações aplicadas ✅
- **Idempotência**: Migrações usam `IF NOT EXISTS` e `DO $$` para serem idempotentes ✅
- **Ordem**: Migrações numeradas sequencialmente (001, 002, ...) ✅

### ⚠️ Verificações Necessárias

#### 4.1. Consistência entre Modelos e Migrações
**Verificar**:
- Se todos os índices definidos nos modelos estão nas migrações
- Se todos os campos definidos nos modelos estão nas migrações
- Se comentários de colunas estão consistentes

#### 4.2. Migração 028 (password_hash)
- **Comentário**: Diz "Hash bcrypt" mas o código usa pbkdf2_sha256
- **Ação**: Corrigir comentário na migração

#### 4.3. Migração 027 (execution_opponent_status_index)
- **Verificar**: Se o índice criado na migração corresponde ao índice no modelo
- **Nota**: Migração cria `ix_technique_executions_opponent_status`, modelo usa `idx_technique_execution_opponent_status`

---

## Resumo de Ações Recomendadas

### Prioridade Alta
1. ✅ Corrigir comentário de `password_hash` em `user.py` e `migrations/028_user_password_hash.sql` (de "bcrypt" para "pbkdf2_sha256")
2. ⚠️ Adicionar índices em `TrainingFeedback.user_id` e `TrainingFeedback.position_id`
3. ⚠️ Adicionar índice em `LessonProgress.lesson_id` (se não existir via unique constraint)
4. ⚠️ Verificar consistência de nomes de índices entre migrações e modelos

### Prioridade Média
5. ⚠️ Adicionar índice em `TechniqueExecution.confirmed_by` (se houver queries frequentes)
6. ⚠️ Adicionar índice em `MissionUsage.usage_type` (se houver queries frequentes)
7. ⚠️ Adicionar índice em `TechniqueExecution.usage_type` (se houver queries frequentes)
8. ⚠️ Revisar cascades de `MissionUsage.lesson_id` e `TechniqueExecution` (mission/lesson/technique) - considerar `SET NULL` em vez de `CASCADE` para manter histórico

### Prioridade Baixa
9. ⚠️ Verificar se emails de professores estão protegidos em schemas
10. ⚠️ Documentar decisões sobre cascades (por que CASCADE vs SET NULL)

---

## Checklist de Verificação

- [ ] Todos os índices necessários estão criados
- [ ] Todos os foreign keys têm cascades apropriados
- [ ] Campos sensíveis não são expostos em schemas de leitura
- [ ] Migrações estão consistentes com modelos
- [ ] Comentários de colunas estão corretos
- [ ] Nomes de índices são consistentes entre modelos e migrações
