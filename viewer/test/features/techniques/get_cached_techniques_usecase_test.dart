import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';
import 'package:viewer/features/techniques/domain/usecases/get_cached_techniques_usecase.dart';

/// Fake leve (sem mockito/codegen) — suficiente para validar o caso de uso.
class _FakeRepo implements TechniqueRepository {
  _FakeRepo(this._cached);

  final Either<TechniqueFailure, List<TechniqueEntity>> _cached;

  @override
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> getCached(
    String academyId,
  ) async =>
      _cached;

  @override
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> syncFromRemote(
    String academyId,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> clearLocalCache(String academyId) async {}

  @override
  Future<Either<TechniqueFailure, TechniqueEntity>> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<TechniqueFailure, TechniqueEntity>> update({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<TechniqueFailure, Unit>> delete({
    required String academyId,
    required String id,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('GetCachedTechniquesUseCase', () {
    test('retorna lista quando o repositório devolve Right', () async {
      final entities = [
        const TechniqueEntity(
          id: '1',
          academyId: 'acad',
          name: 'Arm Lock',
          slug: 'arm-lock',
        ),
      ];
      final useCase = GetCachedTechniquesUseCase(
        _FakeRepo(Right(entities)),
      );

      final result = await useCase('acad');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('esperado Right'),
        (list) {
          expect(list.length, 1);
          expect(list.first.name, 'Arm Lock');
        },
      );
    });

    test('propaga falha quando o repositório devolve Left', () async {
      const failure = CacheTechniqueFailure('erro');
      final useCase = GetCachedTechniquesUseCase(
        _FakeRepo(const Left(failure)),
      );

      final result = await useCase('acad');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, failure),
        (_) => fail('esperado Left'),
      );
    });
  });
}
