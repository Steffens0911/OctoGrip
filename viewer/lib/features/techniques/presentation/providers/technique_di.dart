import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/features/techniques/data/datasources/technique_local_datasource.dart';
import 'package:viewer/features/techniques/data/datasources/technique_remote_datasource.dart';
import 'package:viewer/features/techniques/data/repositories/technique_repository_impl.dart';
import 'package:viewer/features/techniques/domain/repositories/technique_repository.dart';
import 'package:viewer/features/techniques/domain/usecases/clear_techniques_local_cache_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/create_technique_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/delete_technique_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/get_cached_techniques_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/sync_techniques_usecase.dart';
import 'package:viewer/features/techniques/domain/usecases/update_technique_usecase.dart';
import 'package:viewer/services/api_service.dart';

/// Injeção de dependências do módulo (sem depender do Notifier — evita ciclo).
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final techniqueRemoteDataSourceProvider =
    Provider<TechniqueRemoteDataSource>((ref) {
  return TechniqueRemoteDataSourceImpl(ref.watch(apiServiceProvider));
});

final techniqueLocalDataSourceProvider =
    Provider<TechniqueLocalDataSource>((ref) {
  return TechniqueLocalDataSourceImpl();
});

final techniqueRepositoryProvider = Provider<TechniqueRepository>((ref) {
  return TechniqueRepositoryImpl(
    remote: ref.watch(techniqueRemoteDataSourceProvider),
    local: ref.watch(techniqueLocalDataSourceProvider),
  );
});

final getCachedTechniquesUseCaseProvider =
    Provider<GetCachedTechniquesUseCase>((ref) {
  return GetCachedTechniquesUseCase(ref.watch(techniqueRepositoryProvider));
});

final syncTechniquesUseCaseProvider = Provider<SyncTechniquesUseCase>((ref) {
  return SyncTechniquesUseCase(ref.watch(techniqueRepositoryProvider));
});

final clearTechniquesLocalCacheUseCaseProvider =
    Provider<ClearTechniquesLocalCacheUseCase>((ref) {
  return ClearTechniquesLocalCacheUseCase(
    ref.watch(techniqueRepositoryProvider),
  );
});

final createTechniqueUseCaseProvider = Provider<CreateTechniqueUseCase>((ref) {
  return CreateTechniqueUseCase(ref.watch(techniqueRepositoryProvider));
});

final updateTechniqueUseCaseProvider = Provider<UpdateTechniqueUseCase>((ref) {
  return UpdateTechniqueUseCase(ref.watch(techniqueRepositoryProvider));
});

final deleteTechniqueUseCaseProvider = Provider<DeleteTechniqueUseCase>((ref) {
  return DeleteTechniqueUseCase(ref.watch(techniqueRepositoryProvider));
});
