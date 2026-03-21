import 'package:dartz/dartz.dart';

import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';

class UpdateTechniqueUseCase {
  UpdateTechniqueUseCase(this._repository);

  final TechniqueRepository _repository;

  Future<Either<TechniqueFailure, TechniqueEntity>> call({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  }) {
    if (name != null && name.trim().isEmpty) {
      return Future.value(
        const Left(ValidationTechniqueFailure('Nome da técnica é obrigatório.')),
      );
    }
    return _repository.update(
      academyId: academyId,
      id: id,
      name: name?.trim(),
      slug: slug,
      description: description,
      videoUrl: videoUrl,
    );
  }
}
