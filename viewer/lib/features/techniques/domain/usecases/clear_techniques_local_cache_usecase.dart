import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';

/// Limpa apenas o Hive da academia (antes de um novo sync após CRUD).
class ClearTechniquesLocalCacheUseCase {
  ClearTechniquesLocalCacheUseCase(this._repository);

  final TechniqueRepository _repository;

  Future<void> call(String academyId) =>
      _repository.clearLocalCache(academyId);
}
