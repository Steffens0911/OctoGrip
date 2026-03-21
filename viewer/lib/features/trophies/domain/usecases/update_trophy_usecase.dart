import 'package:dartz/dartz.dart';

import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';

class UpdateTrophyUseCase {
  UpdateTrophyUseCase(this._repository);

  final TrophyRepository _repository;

  Future<Either<TrophyFailure, TrophyEntity>> call({
    required String academyId,
    required String id,
    String? techniqueId,
    String? name,
    String? startDate,
    String? endDate,
    int? targetCount,
    String? awardKind,
    int? minDurationDays,
    int? minPointsToUnlock,
    String? minGraduationToUnlock,
  }) {
    return _repository.update(
      academyId: academyId,
      id: id,
      techniqueId: techniqueId,
      name: name,
      startDate: startDate,
      endDate: endDate,
      targetCount: targetCount,
      awardKind: awardKind,
      minDurationDays: minDurationDays,
      minPointsToUnlock: minPointsToUnlock,
      minGraduationToUnlock: minGraduationToUnlock,
    );
  }
}
