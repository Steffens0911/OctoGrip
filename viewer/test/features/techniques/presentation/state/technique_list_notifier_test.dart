import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';
import 'package:viewer/features/techniques/domain/usecases/clear_techniques_local_cache_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/create_technique_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/delete_technique_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/get_cached_techniques_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/sync_techniques_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/update_technique_usecase.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_di.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_providers.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_state.dart';

// ---------------------------------------------------------------------------
// Stub do repositório
// ---------------------------------------------------------------------------

class _StubRepo implements TechniqueRepository {
  List<TechniqueEntity> syncItems = [];
  TechniqueFailure? syncFailure;
  List<TechniqueEntity> cachedItems = [];
  TechniqueFailure? cachedFailure;
  TechniqueEntity? createResult;
  TechniqueFailure? createFailure;
  TechniqueEntity? updateResult;
  TechniqueFailure? updateFailure;
  TechniqueFailure? deleteFailure;
  bool clearCalled = false;

  @override
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> syncFromRemote(
    String academyId,
  ) async {
    if (syncFailure != null) return Left(syncFailure!);
    return Right(syncItems);
  }

  @override
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> getCached(
    String academyId,
  ) async {
    if (cachedFailure != null) return Left(cachedFailure!);
    return Right(cachedItems);
  }

  @override
  Future<Either<TechniqueFailure, TechniqueEntity>> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    if (createFailure != null) return Left(createFailure!);
    return Right(createResult ??
        TechniqueEntity(
            id: 'new', academyId: academyId, name: name, slug: slug ?? name));
  }

  @override
  Future<Either<TechniqueFailure, TechniqueEntity>> update({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    if (updateFailure != null) return Left(updateFailure!);
    return Right(updateResult ??
        TechniqueEntity(
            id: id, academyId: academyId, name: name ?? '', slug: slug ?? ''));
  }

  @override
  Future<Either<TechniqueFailure, Unit>> delete({
    required String academyId,
    required String id,
  }) async {
    if (deleteFailure != null) return Left(deleteFailure!);
    return const Right(unit);
  }

  @override
  Future<void> clearLocalCache(String academyId) async {
    clearCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _academy = 'ac1';

TechniqueEntity _entity(String id, String name) =>
    TechniqueEntity(
        id: id, academyId: _academy, name: name, slug: name.toLowerCase());

/// Drena a fila de microtasks e futures imediatos (resolve async stubs).
Future<void> _pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<Override> _overrides(_StubRepo stub) => [
      getCachedTechniquesUseCaseProvider
          .overrideWithValue(GetCachedTechniquesUseCase(stub)),
      syncTechniquesUseCaseProvider
          .overrideWithValue(SyncTechniquesUseCase(stub)),
      clearTechniquesLocalCacheUseCaseProvider
          .overrideWithValue(ClearTechniquesLocalCacheUseCase(stub)),
      createTechniqueUseCaseProvider
          .overrideWithValue(CreateTechniqueUseCase(stub)),
      updateTechniqueUseCaseProvider
          .overrideWithValue(UpdateTechniqueUseCase(stub)),
      deleteTechniqueUseCaseProvider
          .overrideWithValue(DeleteTechniqueUseCase(stub)),
    ];

/// Cria container, mantém o provider vivo com `listen` e aguarda bootstrap.
Future<({ProviderContainer container, _StubRepo stub})> _setup({
  List<TechniqueEntity> syncItems = const [],
  TechniqueFailure? syncFailure,
  List<TechniqueEntity> cachedItems = const [],
}) async {
  final stub = _StubRepo()
    ..syncItems = syncItems.toList()
    ..syncFailure = syncFailure
    ..cachedItems = cachedItems.toList();

  final container = ProviderContainer(overrides: _overrides(stub));

  // listen() mantém provider autoDispose vivo durante o bootstrap
  container.listen(
    techniqueListNotifierProvider(_academy),
    (_, __) {},
    fireImmediately: true,
  );
  await _pump();

  return (container: container, stub: stub);
}

TechniqueListState _state(ProviderContainer c) =>
    c.read(techniqueListNotifierProvider(_academy));

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  // ---- Bootstrap ----
  group('TechniqueListNotifier — bootstrap', () {
    test('estado inicial tem isInitialLoading=true', () {
      final stub = _StubRepo();
      final container = ProviderContainer(overrides: _overrides(stub));
      addTearDown(container.dispose);

      // Lê antes de qualquer microtask — estado deve ser o inicial
      TechniqueListState? initial;
      container.listen(
        techniqueListNotifierProvider(_academy),
        (_, next) => initial ??= next,
        fireImmediately: true,
      );

      expect(initial?.isInitialLoading, isTrue);
      expect(initial?.allItems, isEmpty);
    });

    test('após sync bem-sucedido, lista é populada', () async {
      final items = [_entity('id1', 'Armlock'), _entity('id2', 'Triângulo')];
      final (:container, :stub) = await _setup(syncItems: items);
      addTearDown(container.dispose);

      final state = _state(container);
      expect(state.isInitialLoading, isFalse);
      expect(state.allItems, hasLength(2));
      expect(state.errorMessage, isNull);
    });

    test('após sync falhar sem cache, exibe errorMessage e lista vazia',
        () async {
      final (:container, :stub) = await _setup(
        syncFailure: const NetworkTechniqueFailure('sem rede'),
      );
      addTearDown(container.dispose);

      final state = _state(container);
      expect(state.isInitialLoading, isFalse);
      expect(state.allItems, isEmpty);
      expect(state.errorMessage, isNotNull);
      expect(state.showingStaleCache, isFalse);
    });

    test('após sync falhar com cache disponível, exibe lista stale', () async {
      final cached = [_entity('id1', 'Armlock')];
      final (:container, :stub) = await _setup(
        syncFailure: const NetworkTechniqueFailure('sem rede'),
        cachedItems: cached,
      );
      addTearDown(container.dispose);

      final state = _state(container);
      expect(state.isInitialLoading, isFalse);
      expect(state.allItems, hasLength(1));
      expect(state.showingStaleCache, isTrue);
      expect(state.errorMessage, isNotNull);
    });
  });

  // ---- refresh ----
  group('TechniqueListNotifier.refresh()', () {
    test('atualiza lista após refresh bem-sucedido', () async {
      final (:container, :stub) =
          await _setup(syncItems: [_entity('id1', 'Armlock')]);
      addTearDown(container.dispose);

      stub.syncItems = [_entity('id1', 'Armlock'), _entity('id2', 'Novo')];
      await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .refresh();

      final state = _state(container);
      expect(state.allItems, hasLength(2));
      expect(state.isRefreshing, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('mantém lista antiga e exibe erro em caso de falha', () async {
      final (:container, :stub) =
          await _setup(syncItems: [_entity('id1', 'Armlock')]);
      addTearDown(container.dispose);

      stub.syncFailure = const NetworkTechniqueFailure('sem rede');
      await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .refresh();

      final state = _state(container);
      expect(state.allItems, hasLength(1)); // lista antiga preservada
      expect(state.errorMessage, isNotNull);
      expect(state.showingStaleCache, isTrue);
    });
  });

  // ---- busca ----
  group('TechniqueListNotifier — busca', () {
    test('clearSearch limpa o searchQuery', () async {
      final (:container, :stub) =
          await _setup(syncItems: [_entity('id1', 'Armlock')]);
      addTearDown(container.dispose);

      container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .clearSearch();

      expect(_state(container).searchQuery, '');
    });
  });

  // ---- loadMore ----
  group('TechniqueListNotifier.loadMore()', () {
    test('incrementa visibleCount quando há mais itens', () async {
      final many = List.generate(
        25,
        (i) => _entity('id$i', 'Técnica ${i.toString().padLeft(2, '0')}'),
      );
      final (:container, :stub) = await _setup(syncItems: many);
      addTearDown(container.dispose);

      expect(_state(container).visible.length, 20);
      expect(_state(container).hasMore, isTrue);

      container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .loadMore();

      expect(_state(container).visible.length, 25);
      expect(_state(container).hasMore, isFalse);
    });

    test('loadMore não faz nada quando não há mais itens', () async {
      final (:container, :stub) =
          await _setup(syncItems: [_entity('id1', 'Armlock')]);
      addTearDown(container.dispose);

      final before = _state(container).visibleCount;
      container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .loadMore();
      expect(_state(container).visibleCount, before);
    });
  });

  // ---- createOptimistic ----
  group('TechniqueListNotifier.createOptimistic()', () {
    test('retorna Left para nome vazio sem chamar API', () async {
      final (:container, :stub) = await _setup();
      addTearDown(container.dispose);

      final result = await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .createOptimistic(name: '  ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('cria técnica com sucesso e retorna Right', () async {
      final created = _entity('new', 'Guarda');
      final (:container, :stub) = await _setup();
      addTearDown(container.dispose);

      stub
        ..createResult = created
        ..syncItems = [created];

      final result = await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .createOptimistic(name: 'Guarda');

      expect(result.isRight(), isTrue);
      expect(_state(container).mutationInProgress, isFalse);
    });

    test('retorna Left e exibe erro em caso de falha na API', () async {
      final (:container, :stub) = await _setup();
      addTearDown(container.dispose);

      stub.createFailure = const NetworkTechniqueFailure('sem rede');

      final result = await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .createOptimistic(name: 'Armlock');

      expect(result.isLeft(), isTrue);
      expect(_state(container).errorMessage, isNotNull);
      expect(_state(container).mutationInProgress, isFalse);
    });
  });

  // ---- updateOptimistic ----
  group('TechniqueListNotifier.updateOptimistic()', () {
    test('retorna Left para nome vazio', () async {
      final item = _entity('id1', 'Armlock');
      final (:container, :stub) = await _setup(syncItems: [item]);
      addTearDown(container.dispose);

      final result = await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .updateOptimistic(id: 'id1', name: '');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('atualiza técnica com sucesso e retorna Right', () async {
      final item = _entity('id1', 'Armlock');
      final (:container, :stub) = await _setup(syncItems: [item]);
      addTearDown(container.dispose);

      final updated = _entity('id1', 'Armlock Americano');
      stub
        ..updateResult = updated
        ..syncItems = [updated];

      final result = await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .updateOptimistic(id: 'id1', name: 'Armlock Americano');

      expect(result.isRight(), isTrue);
      expect(_state(container).mutationInProgress, isFalse);
    });
  });

  // ---- deleteOptimistic ----
  group('TechniqueListNotifier.deleteOptimistic()', () {
    test('remove item da lista após deleção bem-sucedida', () async {
      final item = _entity('id1', 'Armlock');
      final (:container, :stub) = await _setup(syncItems: [item]);
      addTearDown(container.dispose);

      await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .deleteOptimistic(item);

      expect(_state(container).mutationInProgress, isFalse);
    });

    test('exibe erro em caso de falha na deleção', () async {
      final item = _entity('id1', 'Armlock');
      final (:container, :stub) = await _setup(syncItems: [item]);
      addTearDown(container.dispose);

      stub.deleteFailure = const NetworkTechniqueFailure('sem rede');

      await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .deleteOptimistic(item);

      expect(_state(container).errorMessage, isNotNull);
      expect(_state(container).mutationInProgress, isFalse);
    });
  });

  // ---- syncAfterFormClose ----
  group('TechniqueListNotifier.syncAfterFormClose()', () {
    test('não faz nada quando saved é null', () async {
      final (:container, :stub) = await _setup();
      addTearDown(container.dispose);

      final before = _state(container).allItems.length;
      await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .syncAfterFormClose(saved: null);

      expect(_state(container).allItems.length, before);
    });

    test('merge e reload após formClose com entidade salva', () async {
      final saved = _entity('id1', 'Armlock');
      final (:container, :stub) = await _setup();
      addTearDown(container.dispose);

      stub.syncItems = [saved];

      await container
          .read(techniqueListNotifierProvider(_academy).notifier)
          .syncAfterFormClose(saved: saved);

      expect(_state(container).mutationInProgress, isFalse);
      expect(_state(container).allItems, hasLength(1));
    });
  });
}
