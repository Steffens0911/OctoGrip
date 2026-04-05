import 'package:dartz/dartz.dart';

import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';

abstract class TrophyRepository {
  Future<Either<TrophyFailure, List<TrophyEntity>>> getCached(String academyId);

  Future<Either<TrophyFailure, List<TrophyEntity>>> syncFromRemote(String academyId);

  Future<void> clearLocalCache(String academyId);

  Future<Either<TrophyFailure, TrophyEntity>> create({
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
  });

  Future<Either<TrophyFailure, TrophyEntity>> update({
    required String id,
    required String academyId,
    String? techniqueId,
    String? name,
    String? startDate,
    String? endDate,
    int? targetCount,
    String? awardKind,
    int? minDurationDays,
    int? minRewardLevelToUnlock,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
    bool setMaxCountPerOpponent = false,
  });

  Future<Either<TrophyFailure, Unit>> delete({
    required String academyId,
    required String id,
  });
}
