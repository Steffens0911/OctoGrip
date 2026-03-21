import 'package:dartz/dartz.dart';

import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';

class CreateTechniqueUseCase {
  CreateTechniqueUseCase(this._repository);

  final TechniqueRepository _repository;

  Future<Either<TechniqueFailure, TechniqueEntity>> call({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Left(ValidationTechniqueFailure('Nome da técnica é obrigatório.')),
      );
    }
    return _repository.create(
      academyId: academyId,
      name: trimmed,
      slug: slug,
      description: description,
      videoUrl: videoUrl,
    );
  }
}
