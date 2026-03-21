import 'package:dartz/dartz.dart';

import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';

/// Caso de uso: ler apenas o cache (primeiro frame rápido).
class GetCachedTechniquesUseCase {
  GetCachedTechniquesUseCase(this._repository);

  final TechniqueRepository _repository;

  Future<Either<TechniqueFailure, List<TechniqueEntity>>> call(
    String academyId,
  ) {
    return _repository.getCached(academyId);
  }
}
