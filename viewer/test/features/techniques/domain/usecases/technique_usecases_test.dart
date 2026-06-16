import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';
import 'package:viewer/features/techniques/domain/usecases/clear_techniques_local_cache_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/create_technique_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/delete_technique_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/sync_techniques_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/update_technique_usecase.dart';

// ---------------------------------------------------------------------------
// Stub manual do repositório
// ---------------------------------------------------------------------------

class StubTechniqueRepository implements TechniqueRepository {
  static const _defaultEntity = TechniqueEntity(
    id: 'id1',
    academyId: 'ac1',
    name: 'Armlock',
    slug: 'armlock',
  );

  TechniqueEntity? createResult;
  TechniqueFailure? createFailure;
  TechniqueEntity? updateResult;
  TechniqueFailure? updateFailure;
  TechniqueFailure? deleteFailure;
  List<TechniqueEntity> syncList = [];
  TechniqueFailure? syncFailure;
  List<TechniqueEntity> cachedList = [];
  TechniqueFailure? cachedFailure;
  bool clearCalled = false;

  @override
  Future<Either<TechniqueFailure, TechniqueEntity>> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    if (createFailure != null) return Left(createFailure!);
    return Right(createResult ?? _defaultEntity);
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
    return Right(updateResult ?? _defaultEntity);
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
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> syncFromRemote(
    String academyId,
  ) async {
    if (syncFailure != null) return Left(syncFailure!);
    return Right(syncList);
  }

  @override
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> getCached(
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
  late StubTechniqueRepository repo;

  setUp(() => repo = StubTechniqueRepository());

  // ---- CreateTechniqueUseCase ----
  group('CreateTechniqueUseCase', () {
    late CreateTechniqueUseCase uc;
    setUp(() => uc = CreateTechniqueUseCase(repo));

    test('retorna Right para nome válido', () async {
      final result = await uc(academyId: 'ac1', name: 'Armlock');
      expect(result.isRight(), isTrue);
    });

    test('retorna Left(ValidationTechniqueFailure) para nome vazio', () async {
      final result = await uc(academyId: 'ac1', name: '');
      result.fold(
        (f) => expect(f, isA<ValidationTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('retorna Left(ValidationTechniqueFailure) para nome só espaços', () async {
      final result = await uc(academyId: 'ac1', name: '   ');
      result.fold(
        (f) => expect(f, isA<ValidationTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('trim no nome não gera erro de validação', () async {
      final result = await uc(academyId: 'ac1', name: '  Armlock  ');
      expect(result.isRight(), isTrue);
    });

    test('repassa Left do repositório', () async {
      repo.createFailure = const NetworkTechniqueFailure('sem rede');
      final result = await uc(academyId: 'ac1', name: 'Armlock');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- UpdateTechniqueUseCase ----
  group('UpdateTechniqueUseCase', () {
    late UpdateTechniqueUseCase uc;
    setUp(() => uc = UpdateTechniqueUseCase(repo));

    test('retorna Right com entidade atualizada', () async {
      final result = await uc(academyId: 'ac1', id: 'id1', name: 'Armlock v2');
      expect(result.isRight(), isTrue);
    });

    test('retorna Left(ValidationTechniqueFailure) se nome fornecido for vazio', () async {
      final result = await uc(academyId: 'ac1', id: 'id1', name: '   ');
      result.fold(
        (f) => expect(f, isA<ValidationTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('name=null é permitido (atualização parcial)', () async {
      final result = await uc(academyId: 'ac1', id: 'id1');
      expect(result.isRight(), isTrue);
    });

    test('repassa Left do repositório', () async {
      repo.updateFailure = const NetworkTechniqueFailure('timeout');
      final result = await uc(academyId: 'ac1', id: 'id1', name: 'Armlock v2');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- DeleteTechniqueUseCase ----
  group('DeleteTechniqueUseCase', () {
    late DeleteTechniqueUseCase uc;
    setUp(() => uc = DeleteTechniqueUseCase(repo));

    test('retorna Right(unit) em sucesso', () async {
      final result = await uc(academyId: 'ac1', id: 'id1');
      expect(result.isRight(), isTrue);
    });

    test('repassa Left do repositório', () async {
      repo.deleteFailure = const NetworkTechniqueFailure('erro');
      final result = await uc(academyId: 'ac1', id: 'id1');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- SyncTechniquesUseCase ----
  group('SyncTechniquesUseCase', () {
    late SyncTechniquesUseCase uc;
    setUp(() => uc = SyncTechniquesUseCase(repo));

    test('retorna Right com lista do repositório', () async {
      repo.syncList = [
        const TechniqueEntity(id: 'id1', academyId: 'ac1', name: 'A', slug: 'a'),
        const TechniqueEntity(id: 'id2', academyId: 'ac1', name: 'B', slug: 'b'),
      ];
      final result = await uc('ac1');
      result.fold(
        (f) => fail('esperava Right'),
        (list) => expect(list, hasLength(2)),
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
      repo.syncFailure = const NetworkTechniqueFailure('sem rede');
      final result = await uc('ac1');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- ClearTechniquesLocalCacheUseCase ----
  group('ClearTechniquesLocalCacheUseCase', () {
    late ClearTechniquesLocalCacheUseCase uc;
    setUp(() => uc = ClearTechniquesLocalCacheUseCase(repo));

    test('chama repository.clearLocalCache', () async {
      await uc('ac1');
      expect(repo.clearCalled, isTrue);
    });
  });
}
