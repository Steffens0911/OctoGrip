# Módulo Técnicas (Clean Architecture)

Guia geral replicável para outros CRUDs: **[`docs/CRUD_PADRAO_FLUTTER.md`](../../../../docs/CRUD_PADRAO_FLUTTER.md)**.

---

## Estrutura de pastas

```
lib/features/techniques/
├── README.md
├── domain/
│   ├── entities/technique_entity.dart
│   ├── failures/technique_failure.dart
│   ├── repositories/technique_repository.dart
│   └── usecases/
│       ├── clear_techniques_local_cache_usecase.dart
│       ├── create_technique_usecase.dart
│       ├── delete_technique_usecase.dart
│       ├── get_cached_techniques_usecase.dart
│       ├── sync_techniques_usecase.dart
│       └── update_technique_usecase.dart
├── data/
│   ├── models/technique_dto.dart
│   ├── mappers/technique_mapper.dart
│   ├── datasources/
│   │   ├── technique_remote_datasource.dart   # ApiService (+ cacheBust no fetchAll)
│   │   └── technique_local_datasource.dart    # Hive
│   └── repositories/technique_repository_impl.dart
└── presentation/
    ├── providers/
    │   ├── technique_di.dart                  # DI (sem importar o Notifier)
    │   └── technique_providers.dart
    ├── state/
    │   ├── technique_list_state.dart
    │   └── technique_list_notifier.dart
    ├── pages/techniques_list_page.dart
    └── widgets/
        ├── technique_search_bar.dart
        ├── technique_list_card.dart
        └── technique_quick_create_sheet.dart
```

Formulário administrativo completo (legado, partilhado):  
`lib/screens/admin/technique_form_screen.dart` — após salvar, faz `Navigator.pop(context, saved)` com o `Technique` devolvido pela API.

---

## Funcionalidades

| Funcionalidade | Comportamento |
|----------------|---------------|
| **Lista** | Sync com API no arranque; cache Hive como fallback se a rede falhar; aviso de lista possivelmente desatualizada. |
| **Pull-to-refresh** | Novo sync; mantém lista antiga com banner se falhar. |
| **Busca** | Debounce ~280 ms; filtro client-side sobre `allItems`. |
| **Paginação** | Client-side: `visibleCount` aumenta ao aproximar do fim do scroll (`loadMore`). |
| **Criação rápida (FAB)** | Bottom sheet → `createOptimistic` no notifier: API → merge na lista → invalida HTTP + limpa Hive → sync. |
| **Formulário completo** | Ícone na AppBar ou fluxos que abrem `TechniqueFormScreen`; ao gravar, retorna o modelo → `syncAfterFormClose(saved:)` faz merge + reload. |
| **Editar** | Card abre o mesmo form; mesmo fluxo de retorno com `saved`. |
| **Excluir** | Confirmação → API → remove linha de imediato → reload canónico (invalida HTTP + Hive + sync). |
| **Loading de mutação** | Overlay com `mutationInProgress` durante operações longas. |

---

## Decisões técnicas

- **Hive** (Web + mobile); **Either (dartz)** para falhas tipadas.
- **Riverpod `autoDispose.family(academyId)`** para isolar estado por academia.
- **Duas caches**: invalidar **GET** no `ApiService` e **limpar Hive** antes de cada sync pós-mutação.
- **`TechniqueRemoteDataSource.fetchAll`** usa `getTechniques(..., cacheBust: true)` para o sync não ficar com resposta HTTP antiga no browser.
- **Evitar** `return Right(created)` quando `created` é `T?` promovido dentro de `fold` — usar variável local não anulável (ex.: `final savedCreated = created!` após verificar erro).

---

## Testes

```bash
cd viewer
flutter test test/features/techniques/
```

Fakes de repositório devem implementar `clearLocalCache` alinhado ao contrato.
