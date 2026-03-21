import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_di.dart';
import 'package:viewer/features/trophies/presentation/providers/trophy_di.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_state.dart';

class TrophyListNotifier extends AutoDisposeFamilyNotifier<TrophyListState, String> {
  static const _staleCacheHint =
      'Não foi possível sincronizar com o servidor. A lista abaixo pode estar desatualizada.';

  final Logger _log = Logger('TrophyListNotifier');
  Timer? _searchDebounce;
  late String _academyId;

  @override
  TrophyListState build(String academyId) {
    _academyId = academyId;
    ref.onDispose(() => _searchDebounce?.cancel());
    Future.microtask(_bootstrap);
    return TrophyListState(academyId: academyId);
  }

  Future<void> _bootstrap() async {
    final getCached = ref.read(getCachedTrophiesUseCaseProvider);
    final sync = ref.read(syncTrophiesUseCaseProvider);

    final remote = await sync(_academyId);
    await remote.fold<Future<void>>(
      (f) async {
        _log.warning('bootstrap sync failed: ${f.message}');
        final cached = await getCached(_academyId);
        cached.fold(
          (_) {
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

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    final sync = ref.read(syncTrophiesUseCaseProvider);
    final result = await sync(_academyId);
    result.fold(
      (f) {
        _log.warning('refresh sync failed: ${f.message}');
        final hasList = state.allItems.isNotEmpty;
        state = state.copyWith(
          isRefreshing: false,
          errorMessage: hasList ? '$_staleCacheHint\n${f.message}' : f.message,
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

  void _mergeEntityIntoAllItems(TrophyEntity entity) {
    final idx = state.allItems.indexWhere((e) => e.id == entity.id);
    final next = List<TrophyEntity>.from(state.allItems);
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

  Future<void> _reloadListFromServerAfterMutation() async {
    final api = ref.read(apiServiceProvider);
    api.invalidateCache('GET:${api.baseUrl}/trophies');
    await ref.read(clearTrophiesLocalCacheUseCaseProvider)(_academyId);
    final sync = ref.read(syncTrophiesUseCaseProvider);
    final result = await sync(_academyId);
    result.fold(
      (f) {
        _log.warning('reload after mutation failed: ${f.message}');
        final hasList = state.allItems.isNotEmpty;
        state = state.copyWith(
          errorMessage: hasList ? '$_staleCacheHint\n${f.message}' : f.message,
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

  Future<void> syncAfterFormClose({TrophyEntity? saved}) async {
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

  Future<void> deleteOptimistic(TrophyEntity entity) async {
    if (state.mutationInProgress) return;
    state = state.copyWith(mutationInProgress: true, clearError: true);

    final uc = ref.read(deleteTrophyUseCaseProvider);
    final result = await uc(academyId: _academyId, id: entity.id);

    TrophyFailure? fail;
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

    final without =
        state.allItems.where((e) => e.id != entity.id).toList(growable: false);
    state = state.copyWith(allItems: without);

    await _reloadListFromServerAfterMutation();
    state = state.copyWith(mutationInProgress: false);
  }
}
