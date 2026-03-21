import 'dart:math' as math;

import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';

/// Estado imutável da lista (filtro + paginação client-side).
class TechniqueListState {
  const TechniqueListState({
    required this.academyId,
    this.allItems = const [],
    this.searchQuery = '',
    this.isInitialLoading = true,
    this.isRefreshing = false,
    this.errorMessage,
    this.showingStaleCache = false,
    this.pageSize = 20,
    this.visibleCount = 20,
    this.mutationInProgress = false,
  });

  final String academyId;
  final List<TechniqueEntity> allItems;
  final String searchQuery;
  final bool isInitialLoading;
  final bool isRefreshing;
  final String? errorMessage;

  /// Lista vinda do Hive após falha de sync — pode não bater com o servidor.
  final bool showingStaleCache;
  final int pageSize;
  final int visibleCount;
  final bool mutationInProgress;

  /// Lista filtrada por [searchQuery] (case insensitive).
  List<TechniqueEntity> get filtered {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(allItems);
    return allItems
        .where((e) => e.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  /// Fatia para lazy loading / paginação no cliente.
  List<TechniqueEntity> get visible {
    final f = filtered;
    final n = math.min(visibleCount, f.length);
    return f.sublist(0, n);
  }

  bool get hasMore => visible.length < filtered.length;

  bool get isEmpty => filtered.isEmpty && !isInitialLoading;

  TechniqueListState copyWith({
    List<TechniqueEntity>? allItems,
    String? searchQuery,
    bool? isInitialLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    bool? showingStaleCache,
    int? pageSize,
    int? visibleCount,
    bool? mutationInProgress,
  }) {
    return TechniqueListState(
      academyId: academyId,
      allItems: allItems ?? this.allItems,
      searchQuery: searchQuery ?? this.searchQuery,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      showingStaleCache: clearError
          ? false
          : (showingStaleCache ?? this.showingStaleCache),
      pageSize: pageSize ?? this.pageSize,
      visibleCount: visibleCount ?? this.visibleCount,
      mutationInProgress: mutationInProgress ?? this.mutationInProgress,
    );
  }
}
