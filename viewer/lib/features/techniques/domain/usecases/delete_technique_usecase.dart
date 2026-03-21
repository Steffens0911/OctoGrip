import 'package:dartz/dartz.dart';

import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';

class DeleteTechniqueUseCase {
  DeleteTechniqueUseCase(this._repository);

  final TechniqueRepository _repository;

  Future<Either<TechniqueFailure, Unit>> call({
    required String academyId,
    required String id,
  }) {
    return _repository.delete(academyId: academyId, id: id);
  }
}
