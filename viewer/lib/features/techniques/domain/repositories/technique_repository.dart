import 'package:dartz/dartz.dart';

import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';

/// Contrato do repositório: orquestra API + cache local (Hive).
/// A UI/Notifier não conhece HTTP nem chaves de storage.
abstract class TechniqueRepository {
  /// Snapshot do cache (não bloqueia rede).
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> getCached(
    String academyId,
  );

  /// Busca na API, persiste no cache e devolve lista canônica.
  Future<Either<TechniqueFailure, List<TechniqueEntity>>> syncFromRemote(
    String academyId,
  );

  /// Remove lista desta academia do Hive (ex.: após CRUD, antes de novo sync).
  Future<void> clearLocalCache(String academyId);

  Future<Either<TechniqueFailure, TechniqueEntity>> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  });

  Future<Either<TechniqueFailure, TechniqueEntity>> update({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  });

  Future<Either<TechniqueFailure, Unit>> delete({
    required String academyId,
    required String id,
  });
}
