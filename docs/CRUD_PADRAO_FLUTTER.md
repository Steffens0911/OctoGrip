# Padrão de CRUD no Flutter (referência: módulo **Técnicas**)

Este documento descreve o que foi implementado no CRUD de técnicas (`viewer/lib/features/techniques/`) para que o mesmo padrão possa ser aplicado a **lições, missões, vídeos, utilizadores**, etc.

---

## Objetivos do padrão

1. **Lista sempre coerente com o servidor** após criar, editar ou excluir — sem linhas “fantasma” nem dados antigos por cache.
2. **Web + mobile**: cache local com **Hive** (sem depender de SQLite no browser).
3. **Erros explícitos** na UI com **Either** (`dartz`), sem exceções a atravessar camadas sem controlo.
4. **Duas fontes de cache a tratar**:
   - **Cache HTTP em memória** no `ApiService` (`_getWithCache`).
   - **Persistência Hive** listas por academia/recurso.

---

## Arquitetura em camadas

| Camada | Responsabilidade |
|--------|------------------|
| **Domain** | `Entity`, `Failure`, contrato `Repository`, **UseCases** (incl. `sync`, `getCached`, `clearLocalCache`). |
| **Data** | `Dto`, `Mapper`, `RemoteDataSource` (delega ao `ApiService`), `LocalDataSource` (Hive), `RepositoryImpl`. |
| **Presentation** | Riverpod: `State`, `Notifier` (mutações + lista), `Page`, widgets (lista, sheet rápido, etc.). |

**Formulários “legacy”** (`lib/screens/admin/*_form_screen.dart`) podem continuar a usar `ApiService` direto; a **lista nova** (Riverpod) deve **receber o modelo gravado** no `Navigator.pop` e fundir na lista (ver abaixo).

---

## Fluxo após qualquer mutação (Create / Update / Delete)

Ordem recomendada (implementada no `TechniqueListNotifier`):

1. **Invalidar cache HTTP** do GET da coleção, ex.:  
   `api.invalidateCache('GET:${api.baseUrl}/techniques');`
2. **Limpar cache local** (Hive) dessa lista/academia:  
   `clearLocalCacheUseCase(academyId)`.
3. **Sincronizar com a API**: `syncFromRemote(academyId)` (ou equivalente) e substituir `state.allItems` pelo resultado **canónico**.

Durante o passo 3, a UI pode mostrar **`mutationInProgress`** (overlay semi-transparente + `CircularProgressIndicator`).

### Por que não basta “só dar refresh”?

- O browser pode servir **GET em cache** se não houver bust/invalidação.
- O Hive pode manter **lista antiga** se não for limpa antes do novo sync.
- **`Either.fold` com ramos `async`**: em Dart, evitar padrões onde o `await` fica dentro de `fold` de forma que o fluxo não seja linear; preferir `fold` só para ler `Left`/`Right` e depois código imperativo com `await` (como no delete).

---

## Create e Update (lista + notifier)

Após sucesso na API:

1. **Fundir** o `Entity` devolvido na lista local (`_mergeEntityIntoAllItems`): inserir ou substituir por `id`, ordenar (ex.: por nome).
2. Chamar **`_reloadListFromServerAfterMutation()`** (invalidar HTTP + limpar Hive + `sync`).

**Promover tipo não-nulo:** se usar variáveis `TechniqueEntity?` preenchidas em `fold`, o analisador pode não promover para não-null; usar variável local `final saved = created!` **depois** do `if (fail != null) return` antes de `return Right(saved)`.

---

## Delete

1. Chamar API; se falhar → erro na UI, **não** alterar lista.
2. Se sucesso → **remover já** o item de `allItems` (feedback imediato).
3. `_reloadListFromServerAfterMutation()` para reconciliar com o servidor.

---

## Formulário completo (Navigator)

Problema comum: `Navigator.pop(context)` **sem resultado** → o ecrã da lista não sabe o que foi gravado e `syncAfterFormClose(saved: null)` **não faz nada**.

**Solução:**

- No `_save` do form: `final saved = await _api.create...` / `update...` → `Navigator.pop(context, saved)`.
- Na lista:  
  `final saved = await Navigator.push<MeuModelo?>(...)`  
  e depois converter para `Entity` e chamar  
  `notifier.syncAfterFormClose(saved: entity)`  
  (que faz merge + reload completo).

Se o utilizador só fechar sem gravar, `saved == null` → opcionalmente não recarregar (comportamento atual das técnicas).

---

## Criação rápida (FAB / bottom sheet)

O sheet chama diretamente o **notifier** (`createOptimistic`), que já faz merge + `_reloadListFromServerAfterMutation` após sucesso — **não depende** do `pop` do form.

---

## API: `cacheBust` e `invalidateCache`

- **GET listagem**: expor `cacheBust: true` na query (`_t=timestamp`) para o **sync** e para ecrãs que precisem de dados frescos (ex.: sugestões no form).
- **POST/PUT/DELETE**: após sucesso, chamar `invalidateCache('GET:.../recurso')` no método correspondente do `ApiService` (já feito para técnicas; replicar por recurso).

---

## Estados de UI úteis

| Estado | Uso |
|--------|-----|
| `isInitialLoading` | Primeira carga; lista vazia + spinner. |
| `isRefreshing` | Pull-to-refresh. |
| `mutationInProgress` | Qualquer CRUD em curso; desativar ações e mostrar overlay. |
| `showingStaleCache` + mensagem | Sync falhou mas há lista em cache; avisar e oferecer “Tentar novamente”. |
| `errorMessage` | Falha sem lista útil ou mensagem complementar. |

---

## Riverpod

- **`autoDispose.family` por `academyId`** (ou outro scope): estado isolado e libertado ao sair do ecrã.
- **Providers de use cases** em ficheiro tipo `*_di.dart` **sem** importar o Notifier (evita dependências circulares).

---

## Testes

- Repositório fake deve implementar **`clearLocalCache`** se o contrato exigir.
- Testes de use case com `Either` e mocks do repositório.

Comando exemplo:

```bash
cd viewer
flutter test test/features/techniques/
```

---

## Checklist para um novo CRUD

- [ ] **Domain**: `Entity`, `Failure`, `Repository` com `getCached`, `syncFromRemote`, `clearLocalCache`, `create`, `update`, `delete`.
- [ ] **Data**: DTO, mapper, remote (com `cacheBust` no `fetchAll` se aplicável), local Hive, `RepositoryImpl`.
- [ ] **UseCases**: pelo menos `Sync`, `GetCached`, `ClearLocalCache`, + CRUD.
- [ ] **ApiService**: `invalidateCache` nos mutadores; GET com `cacheBust` opcional.
- [ ] **Notifier**: `refresh`, `_reloadListFromServerAfterMutation`, `createOptimistic`, `updateOptimistic`, `deleteOptimistic`, `syncAfterFormClose({Entity? saved})`, `_mergeEntityIntoAllItems`, tratamento de `stale cache` no bootstrap/refresh.
- [ ] **Page**: overlay se `mutationInProgress`; `Navigator.push` tipado com retorno do form; conversão modelo legacy → `Entity` se necessário.
- [ ] **Form**: `Navigator.pop(context, saved)` com o objeto devolvido pela API.
- [ ] **Documentação** do módulo em `features/<nome>/README.md` + ligação a este ficheiro.

---

## Referência de ficheiros (técnicas)

| Ficheiro | Função |
|----------|--------|
| `technique_list_notifier.dart` | Lógica de lista, mutações, merge, reload, debounce, paginação client-side |
| `technique_list_state.dart` | Estado imutável + getters (`filtered`, `visible`, `hasMore`) |
| `techniques_list_page.dart` | UI, navegação para form com `saved` |
| `technique_quick_create_sheet.dart` | Criação rápida via notifier |
| `technique_repository_impl.dart` | Orquestra remote + local |
| `clear_techniques_local_cache_usecase.dart` | UC fino para limpar Hive |
| `screens/admin/technique_form_screen.dart` | Form legacy + `pop` com `Technique` |

---

## Manutenção

Ao duplicar o padrão, **alinhar nomes** (`LessonListNotifier`, `clearLessonsLocalCache`, etc.) e **uma chave Hive / endpoint** por recurso. Manter este documento atualizado quando o primeiro novo CRUD “piloto” (ex.: lições) fechar lições aprendidas adicionais.
