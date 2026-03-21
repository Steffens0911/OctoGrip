import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/features/techniques/presentation/providers/technique_di.dart';
import 'package:viewer/features/trophies/data/datasources/trophy_local_datasource.dart';
import 'package:viewer/features/trophies/data/datasources/trophy_remote_datasource.dart';
import 'package:viewer/features/trophies/data/repositories/trophy_repository_impl.dart';
import 'package:viewer/features/trophies/domain/repositories/trophy_repository.dart';
import 'package:viewer/features/trophies/domain/usecases/clear_trophies_local_cache_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/create_trophy_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/delete_trophy_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/get_cached_trophies_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/sync_trophies_usecase.dart';
import 'package:viewer/features/trophies/domain/usecases/update_trophy_usecase.dart';

final trophyRemoteDataSourceProvider = Provider<TrophyRemoteDataSource>((ref) {
  return TrophyRemoteDataSourceImpl(ref.watch(apiServiceProvider));
});

final trophyLocalDataSourceProvider = Provider<TrophyLocalDataSource>((ref) {
  return TrophyLocalDataSourceImpl();
});

final trophyRepositoryProvider = Provider<TrophyRepository>((ref) {
  return TrophyRepositoryImpl(
    remote: ref.watch(trophyRemoteDataSourceProvider),
    local: ref.watch(trophyLocalDataSourceProvider),
  );
});

final getCachedTrophiesUseCaseProvider = Provider<GetCachedTrophiesUseCase>((ref) {
  return GetCachedTrophiesUseCase(ref.watch(trophyRepositoryProvider));
});

final syncTrophiesUseCaseProvider = Provider<SyncTrophiesUseCase>((ref) {
  return SyncTrophiesUseCase(ref.watch(trophyRepositoryProvider));
});

final clearTrophiesLocalCacheUseCaseProvider =
    Provider<ClearTrophiesLocalCacheUseCase>((ref) {
  return ClearTrophiesLocalCacheUseCase(ref.watch(trophyRepositoryProvider));
});

final createTrophyUseCaseProvider = Provider<CreateTrophyUseCase>((ref) {
  return CreateTrophyUseCase(ref.watch(trophyRepositoryProvider));
});

final updateTrophyUseCaseProvider = Provider<UpdateTrophyUseCase>((ref) {
  return UpdateTrophyUseCase(ref.watch(trophyRepositoryProvider));
});

final deleteTrophyUseCaseProvider = Provider<DeleteTrophyUseCase>((ref) {
  return DeleteTrophyUseCase(ref.watch(trophyRepositoryProvider));
});
