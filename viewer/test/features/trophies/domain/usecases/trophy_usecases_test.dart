import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';
import 'package:viewer/features/trophies/domain/usecases/clear_trophies_local_cache_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/create_trophy_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/delete_trophy_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/sync_trophies_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/update_trophy_usecase.dart';

// ---------------------------------------------------------------------------
// Stub do repositório
// ---------------------------------------------------------------------------

class StubTrophyRepository implements TrophyRepository {
  static const _default = TrophyEntity(
    id: 'tr1',
    academyId: 'ac1',
    techniqueId: 'tech1',
    name: 'Armlock 5x',
    startDateIso: '2026-01-01',
    endDateIso: '2026-12-31',
    targetCount: 5,
    awardKind: 'trophy',
  );

  TrophyEntity? createResult;
  TrophyFailure? createFailure;
  TrophyEntity? updateResult;
  TrophyFailure? updateFailure;
  TrophyFailure? deleteFailure;
  List<TrophyEntity> syncList = [];
  TrophyFailure? syncFailure;
  List<TrophyEntity> cachedList = [];
  TrophyFailure? cachedFailure;
  bool clearCalled = false;

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
  }) async {
    if (createFailure != null) return Left(createFailure!);
    return Right(createResult ?? _default);
  }

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
  }) async {
    if (updateFailure != null) return Left(updateFailure!);
    return Right(updateResult ?? _default);
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
  Future<Either<TrophyFailure, List<TrophyEntity>>> syncFromRemote(
    String academyId,
  ) async {
    if (syncFailure != null) return Left(syncFailure!);
    return Right(syncList);
  }

  @override
  Future<Either<TrophyFailure, List<TrophyEntity>>> getCached(
    String academyId,
  ) async {
    if (cachedFailure != null) return Left(cachedFailure!);
    return Right(cachedList);
  }

  @override
  Future<void> clearLocalCache(String academyId) async {
    clearCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  late StubTrophyRepository repo;
  setUp(() => repo = StubTrophyRepository());

  // ---- CreateTrophyUseCase ----
  group('CreateTrophyUseCase', () {
    late CreateTrophyUseCase uc;
    setUp(() => uc = CreateTrophyUseCase(repo));

    test('retorna Right com entidade criada', () async {
      final result = await uc(
        academyId: 'ac1',
        techniqueId: 'tech1',
        name: 'Armlock 5x',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        targetCount: 5,
        awardKind: 'trophy',
      );
      expect(result.isRight(), isTrue);
    });

    test('repassa Left do repositório', () async {
      repo.createFailure = const NetworkTrophyFailure('sem rede');
      final result = await uc(
        academyId: 'ac1',
        techniqueId: 'tech1',
        name: 'Armlock 5x',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        targetCount: 5,
        awardKind: 'trophy',
      );
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- UpdateTrophyUseCase ----
  group('UpdateTrophyUseCase', () {
    late UpdateTrophyUseCase uc;
    setUp(() => uc = UpdateTrophyUseCase(repo));

    test('retorna Right com entidade atualizada', () async {
      final result = await uc(academyId: 'ac1', id: 'tr1', name: 'Armlock 10x');
      expect(result.isRight(), isTrue);
    });

    test('todos os parâmetros são opcionais exceto id e academyId', () async {
      final result = await uc(academyId: 'ac1', id: 'tr1');
      expect(result.isRight(), isTrue);
    });

    test('repassa Left do repositório', () async {
      repo.updateFailure = const NetworkTrophyFailure('timeout');
      final result = await uc(academyId: 'ac1', id: 'tr1');
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- DeleteTrophyUseCase ----
  group('DeleteTrophyUseCase', () {
    late DeleteTrophyUseCase uc;
    setUp(() => uc = DeleteTrophyUseCase(repo));

    test('retorna Right(unit) em sucesso', () async {
      final result = await uc(academyId: 'ac1', id: 'tr1');
      expect(result.isRight(), isTrue);
    });

    test('repassa Left do repositório', () async {
      repo.deleteFailure = const NetworkTrophyFailure('erro');
      final result = await uc(academyId: 'ac1', id: 'tr1');
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- SyncTrophiesUseCase ----
  group('SyncTrophiesUseCase', () {
    late SyncTrophiesUseCase uc;
    setUp(() => uc = SyncTrophiesUseCase(repo));

    test('retorna Right com lista', () async {
      repo.syncList = [StubTrophyRepository._default];
      final result = await uc('ac1');
      result.fold(
        (f) => fail('esperava Right'),
        (list) => expect(list, hasLength(1)),
      );
    });

    test('retorna Right([]) quando lista vazia', () async {
      final result = await uc('ac1');
      result.fold(
        (f) => fail('esperava Right'),
        (list) => expect(list, isEmpty),
      );
    });

    test('repassa Left do repositório', () async {
      repo.syncFailure = const NetworkTrophyFailure('sem rede');
      final result = await uc('ac1');
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- ClearTrophiesLocalCacheUseCase ----
  group('ClearTrophiesLocalCacheUseCase', () {
    late ClearTrophiesLocalCacheUseCase uc;
    setUp(() => uc = ClearTrophiesLocalCacheUseCase(repo));

    test('chama repository.clearLocalCache', () async {
      await uc('ac1');
      expect(repo.clearCalled, isTrue);
    });
  });
}
