import 'package:dartz/dartz.dart';

import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';

class SyncTrophiesUseCase {
  SyncTrophiesUseCase(this._repository);

  final TrophyRepository _repository;

  Future<Either<TrophyFailure, List<TrophyEntity>>> call(String academyId) {
    return _repository.syncFromRemote(academyId);
  }
}
