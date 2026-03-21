import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';

class ClearTrophiesLocalCacheUseCase {
  ClearTrophiesLocalCacheUseCase(this._repository);

  final TrophyRepository _repository;

  Future<void> call(String academyId) => _repository.clearLocalCache(academyId);
}
