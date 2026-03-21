import 'package:dartz/dartz.dart';

import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';

class DeleteTrophyUseCase {
  DeleteTrophyUseCase(this._repository);

  final TrophyRepository _repository;

  Future<Either<TrophyFailure, Unit>> call({
    required String academyId,
    required String id,
  }) {
    return _repository.delete(academyId: academyId, id: id);
  }
}
