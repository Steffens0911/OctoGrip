import 'package:dartz/dartz.dart';

import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';

class CreateTrophyUseCase {
  CreateTrophyUseCase(this._repository);

  final TrophyRepository _repository;

  Future<Either<TrophyFailure, TrophyEntity>> call({
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
  }) {
    return _repository.create(
      academyId: academyId,
      techniqueId: techniqueId,
      name: name,
      startDate: startDate,
      endDate: endDate,
      targetCount: targetCount,
      awardKind: awardKind,
      minDurationDays: minDurationDays,
      minRewardLevelToUnlock: minRewardLevelToUnlock,
      minGraduationToUnlock: minGraduationToUnlock,
      maxCountPerOpponent: maxCountPerOpponent,
    );
  }
}
