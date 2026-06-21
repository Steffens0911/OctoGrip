import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';
import 'package:viewer/features/trophies/domain/usecases/clear_trophies_local_cache_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/delete_trophy_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/get_cached_trophies_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/sync_trophies_usecase.dart';
import 'package:viewer/features/trophies/presentation/providers/trophy_di.dart';
import 'package:viewer/features/trophies/presentation/providers/trophy_providers.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_di.dart';
import 'package:viewer/services/api_service.dart';

class _StubRepo implements TrophyRepository {
  List<TrophyEntity> syncItems = [];
  TrophyFailure? syncFailure;
  List<TrophyEntity> cachedItems = [];
  TrophyFailure? cachedFailure;
  TrophyFailure? deleteFailure;
  bool clearCalled = false;

  @override
  Future<Either<TrophyFailure, List<TrophyEntity>>> syncFromRemote(
    String academyId,
  ) async {
    if (syncFailure != null) return Left(syncFailure!);
    return Right(syncItems);
  }

  @override
  Future<Either<TrophyFailure, List<TrophyEntity>>> getCached(
    String academyId,
  ) async {
    if (cachedFailure != null) return Left(cachedFailure!);
    return Right(cachedItems);
  }

  @override
  Future<Either<TrophyFailure, Unit>> delete({
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

  @override
  Future<Either<TrophyFailure, TrophyEntity>> create({
    required String academyId,
    required String techniqueId,
    required String name,
    required String startDate,
    required String endDate,
    required int targetCount,
    required String awardKind,
    int? minDurationDays,
    int minRewardLevelToUnlock = 0,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<TrophyFailure, TrophyEntity>> update({
    required String id,
    required String academyId,
    String? techniqueId,
    String? name,
    String? startDate,
    String? endDate,
    int? targetCount,
    String? awardKind,
    int? minDurationDays,
    int? minRewardLevelToUnlock,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
    bool setMaxCountPerOpponent = false,
  }) async =>
      throw UnimplementedError();
}

/// Drena a fila de microtasks e futures imediatos (resolve async stubs).
Future<void> _pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<Override> _overrides(_StubRepo stub) => [
      getCachedTrophiesUseCaseProvider
          .overrideWithValue(GetCachedTrophiesUseCase(stub)),
      syncTrophiesUseCaseProvider
          .overrideWithValue(SyncTrophiesUseCase(stub)),
      clearTrophiesLocalCacheUseCaseProvider
          .overrideWithValue(ClearTrophiesLocalCacheUseCase(stub)),
      deleteTrophyUseCaseProvider.overrideWithValue(DeleteTrophyUseCase(stub)),
      apiServiceProvider.overrideWithValue(ApiService()),
    ];

Future<({ProviderContainer container, _StubRepo stub})> _setup({
  List<TrophyEntity> syncItems = const [],
  TrophyFailure? syncFailure,
  List<TrophyEntity> cachedItems = const [],
  TrophyFailure? cachedFailure,
}) async {
  final stub = _StubRepo()
    ..syncItems = syncItems
    ..syncFailure = syncFailure
    ..cachedItems = cachedItems
    ..cachedFailure = cachedFailure;

  final container = ProviderContainer(overrides: _overrides(stub));
  // Mantém o provider vivo e aguarda o bootstrap.
  container.listen(
    trophyListNotifierProvider('ac1'),
    (_, __) {},
    fireImmediately: true,
  );
  await _pump();
  return (container: container, stub: stub);
}

const _t1 = TrophyEntity(
  id: 'tr1',
  academyId: 'ac1',
  techniqueId: 'tech1',
  name: 'Armlock',
  startDateIso: '2026-01-01',
  endDateIso: '2026-12-31',
  targetCount: 5,
  awardKind: 'trophy',
);

void main() {
  group('TrophyListNotifier bootstrap — sync ok', () {
    test('carrega lista após bootstrap', () async {
      final (:container, stub: _) = await _setup(syncItems: [_t1]);
      addTearDown(container.dispose);

      final s = container.read(trophyListNotifierProvider('ac1'));
      expect(s.isInitialLoading, isFalse);
      expect(s.allItems, contains(_t1));
    });
  });

  group('TrophyListNotifier bootstrap — sync falha, sem cache', () {
    test('exibe erro quando sync e cache falham', () async {
      final (:container, stub: _) = await _setup(
        syncFailure: const NetworkTrophyFailure('sem rede'),
        cachedFailure: const CacheTrophyFailure('sem cache'),
      );
      addTearDown(container.dispose);

      final s = container.read(trophyListNotifierProvider('ac1'));
      expect(s.isInitialLoading, isFalse);
      expect(s.errorMessage, isNotNull);
    });
  });

  group('TrophyListNotifier.clearSearch', () {
    test('limpa searchQuery', () async {
      final (:container, stub: _) = await _setup(syncItems: []);
      addTearDown(container.dispose);

      container.read(trophyListNotifierProvider('ac1').notifier).clearSearch();

      final s = container.read(trophyListNotifierProvider('ac1'));
      expect(s.searchQuery, isEmpty);
    });
  });

  group('TrophyListNotifier.loadMore', () {
    test('não muda visibleCount quando não há mais itens', () async {
      final (:container, stub: _) = await _setup(syncItems: []);
      addTearDown(container.dispose);

      final before =
          container.read(trophyListNotifierProvider('ac1')).visibleCount;
      container
          .read(trophyListNotifierProvider('ac1').notifier)
          .loadMore(); // hasMore=false
      final after =
          container.read(trophyListNotifierProvider('ac1')).visibleCount;

      expect(after, before);
    });
  });

  group('TrophyListNotifier.refresh', () {
    test('atualiza lista após refresh bem-sucedido', () async {
      final (:container, stub: _) = await _setup(syncItems: [_t1]);
      addTearDown(container.dispose);

      await container
          .read(trophyListNotifierProvider('ac1').notifier)
          .refresh();

      final s = container.read(trophyListNotifierProvider('ac1'));
      expect(s.isRefreshing, isFalse);
      expect(s.allItems, contains(_t1));
    });
  });

  group('TrophyListNotifier.deleteOptimistic', () {
    test('exibe erro quando delete falha', () async {
      final stub = _StubRepo()
        ..syncItems = [_t1]
        ..deleteFailure = const NetworkTrophyFailure('falha ao excluir');

      final container = ProviderContainer(overrides: _overrides(stub));
      addTearDown(container.dispose);

      container.listen(
        trophyListNotifierProvider('ac1'),
        (_, __) {},
        fireImmediately: true,
      );
      await _pump();

      await container
          .read(trophyListNotifierProvider('ac1').notifier)
          .deleteOptimistic(_t1);

      final s = container.read(trophyListNotifierProvider('ac1'));
      expect(s.errorMessage, isNotNull);
      expect(s.mutationInProgress, isFalse);
    });
  });
}
