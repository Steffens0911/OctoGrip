import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_di.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_state.dart';

/// Orquestra rede, Hive e mutações: após CRUD, limpa cache local e recarrega da API.
class TechniqueListNotifier
    extends AutoDisposeFamilyNotifier<TechniqueListState, String> {
  static const _staleCacheHint =
      'Não foi possível sincronizar com o servidor. A lista abaixo pode estar desatualizada.';

  final Logger _log = Logger('TechniqueListNotifier');
  Timer? _searchDebounce;

  late final String _academyId;

  @override
  TechniqueListState build(String academyId) {
    _academyId = academyId;
    ref.onDispose(() => _searchDebounce?.cancel());
    Future.microtask(_bootstrap);
    return TechniqueListState(academyId: academyId);
  }

  Future<void> _bootstrap() async {
    final getCached = ref.read(getCachedTechniquesUseCaseProvider);
    final sync = ref.read(syncTechniquesUseCaseProvider);

    final remote = await sync(_academyId);
    await remote.fold<Future<void>>(
      (f) async {
        _log.warning('bootstrap sync failed: ${f.message}');
        final cached = await getCached(_academyId);
        cached.fold(
          (cacheFailure) {
            _log.fine('cache fallback miss: ${cacheFailure.message}');
            state = state.copyWith(
              allItems: const [],
              isInitialLoading: false,
              visibleCount: state.pageSize,
              errorMessage: f.message,
              showingStaleCache: false,
            );
          },
          (list) {
            if (list.isEmpty) {
              state = state.copyWith(
                allItems: const [],
                isInitialLoading: false,
                visibleCount: state.pageSize,
                errorMessage: f.message,
                showingStaleCache: false,
              );
            } else {
              state = state.copyWith(
                allItems: list,
                isInitialLoading: false,
                visibleCount: state.pageSize,
                errorMessage: '$_staleCacheHint\n${f.message}',
                showingStaleCache: true,
              );
            }
          },
        );
      },
      (list) async {
        state = state.copyWith(
          allItems: list,
          isInitialLoading: false,
          visibleCount: state.pageSize,
          clearError: true,
        );
      },
    );
  }

  /// Pull-to-refresh: reconcilia com API (mantém lista em falha parcial).
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final sync = ref.read(syncTechniquesUseCaseProvider);
    final result = await sync(_academyId);
    result.fold(
      (f) {
        _log.warning('refresh sync failed: ${f.message}');
        final hasList = state.allItems.isNotEmpty;
        state = state.copyWith(
          isRefreshing: false,
          errorMessage: hasList
              ? '$_staleCacheHint\n${f.message}'
              : f.message,
          showingStaleCache: hasList,
        );
      },
      (list) {
        state = state.copyWith(
          allItems: list,
          isRefreshing: false,
          visibleCount: state.pageSize,
          clearError: true,
        );
      },
    );
  }

  /// Insere ou substitui na lista local (ordenado por nome) antes do sync com API.
  void _mergeEntityIntoAllItems(TechniqueEntity entity) {
    final idx = state.allItems.indexWhere((e) => e.id == entity.id);
    final next = List<TechniqueEntity>.from(state.allItems);
    if (idx >= 0) {
      next[idx] = entity;
    } else {
      next.add(entity);
    }
    next.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    state = state.copyWith(allItems: next);
  }

  /// Invalida cache HTTP + Hive e busca lista canónica no servidor.
  Future<void> _reloadListFromServerAfterMutation() async {
    final api = ref.read(apiServiceProvider);
    api.invalidateCache('GET:${api.baseUrl}/techniques');
    await ref.read(clearTechniquesLocalCacheUseCaseProvider)(_academyId);
    final sync = ref.read(syncTechniquesUseCaseProvider);
    final result = await sync(_academyId);
    result.fold(
      (f) {
        _log.warning('reload after mutation failed: ${f.message}');
        final hasList = state.allItems.isNotEmpty;
        state = state.copyWith(
          errorMessage: hasList
              ? '$_staleCacheHint\n${f.message}'
              : f.message,
          showingStaleCache: hasList,
        );
      },
      (list) {
        state = state.copyWith(
          allItems: list,
          visibleCount: state.pageSize,
          clearError: true,
        );
      },
    );
  }

  /// Após voltar do formulário completo: se houve gravação, [saved] traz o registo da API.
  Future<void> syncAfterFormClose({TechniqueEntity? saved}) async {
    if (saved == null) return;
    state = state.copyWith(mutationInProgress: true, clearError: true);
    _mergeEntityIntoAllItems(saved);
    await _reloadListFromServerAfterMutation();
    state = state.copyWith(mutationInProgress: false);
  }

  void onSearchChanged(String raw) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      state = state.copyWith(
        searchQuery: raw,
        visibleCount: state.pageSize,
      );
    });
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    state = state.copyWith(
      searchQuery: '',
      visibleCount: state.pageSize,
    );
  }

  void loadMore() {
    if (!state.hasMore) return;
    state = state.copyWith(
      visibleCount: state.visibleCount + state.pageSize,
    );
  }

  /// Exclusão: API primeiro; remove da UI de imediato; depois limpa caches e reconcilia.
  Future<void> deleteOptimistic(TechniqueEntity entity) async {
    if (state.mutationInProgress) return;
    state = state.copyWith(mutationInProgress: true, clearError: true);

    final uc = ref.read(deleteTechniqueUseCaseProvider);
    final result = await uc(academyId: _academyId, id: entity.id);

    TechniqueFailure? fail;
    result.fold(
      (f) => fail = f,
      (_) {},
    );
    if (fail != null) {
      state = state.copyWith(
        mutationInProgress: false,
        errorMessage: fail!.message,
        showingStaleCache: false,
      );
      return;
    }

    final without = state.allItems
        .where((e) => e.id != entity.id)
        .toList(growable: false);
    state = state.copyWith(allItems: without);

    await _reloadListFromServerAfterMutation();
    state = state.copyWith(mutationInProgress: false);
  }

  /// Criação: sem linha otimista; após sucesso, limpa cache e recarrega.
  Future<Either<TechniqueFailure, TechniqueEntity>> createOptimistic({
    required String name,
    String? description,
    String? videoUrl,
  }) async {
    if (state.mutationInProgress) {
      return const Left(
        ValidationTechniqueFailure('Aguarde a operação anterior.'),
      );
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationTechniqueFailure('Nome da técnica é obrigatório.'));
    }

    state = state.copyWith(mutationInProgress: true, clearError: true);

    final uc = ref.read(createTechniqueUseCaseProvider);
    final result = await uc(
      academyId: _academyId,
      name: trimmed,
      description: description,
      videoUrl: videoUrl,
    );

    TechniqueFailure? createFail;
    TechniqueEntity? created;
    result.fold(
      (f) => createFail = f,
      (c) => created = c,
    );
    if (createFail != null) {
      state = state.copyWith(
        mutationInProgress: false,
        errorMessage: createFail!.message,
        showingStaleCache: false,
      );
      return Left(createFail!);
    }

    final savedCreated = created!;
    _mergeEntityIntoAllItems(savedCreated);
    await _reloadListFromServerAfterMutation();
    state = state.copyWith(mutationInProgress: false);
    return Right(savedCreated);
  }

  /// Atualização: API + reload completo da lista.
  Future<Either<TechniqueFailure, TechniqueEntity>> updateOptimistic({
    required String id,
    required String name,
    String? description,
    String? videoUrl,
  }) async {
    if (state.mutationInProgress) {
      return const Left(
        ValidationTechniqueFailure('Aguarde a operação anterior.'),
      );
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationTechniqueFailure('Nome da técnica é obrigatório.'));
    }

    state = state.copyWith(mutationInProgress: true, clearError: true);

    final uc = ref.read(updateTechniqueUseCaseProvider);
    final result = await uc(
      academyId: _academyId,
      id: id,
      name: trimmed,
      description: description,
      videoUrl: videoUrl,
    );

    TechniqueFailure? updateFail;
    TechniqueEntity? updated;
    result.fold(
      (f) => updateFail = f,
      (u) => updated = u,
    );
    if (updateFail != null) {
      state = state.copyWith(
        mutationInProgress: false,
        errorMessage: updateFail!.message,
        showingStaleCache: false,
      );
      return Left(updateFail!);
    }

    final savedUpdated = updated!;
    _mergeEntityIntoAllItems(savedUpdated);
    await _reloadListFromServerAfterMutation();
    state = state.copyWith(mutationInProgress: false);
    return Right(savedUpdated);
  }
}
