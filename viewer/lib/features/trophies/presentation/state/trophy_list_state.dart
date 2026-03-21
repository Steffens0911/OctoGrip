import 'dart:math' as math;

import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';

class TrophyListState {
  const TrophyListState({
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
  final List<TrophyEntity> allItems;
  final String searchQuery;
  final bool isInitialLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final bool showingStaleCache;
  final int pageSize;
  final int visibleCount;
  final bool mutationInProgress;

  List<TrophyEntity> get filtered {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(allItems);
    return allItems
        .where((e) => e.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  List<TrophyEntity> get visible {
    final f = filtered;
    final n = math.min(visibleCount, f.length);
    return f.sublist(0, n);
  }

  bool get hasMore => visible.length < filtered.length;

  TrophyListState copyWith({
    List<TrophyEntity>? allItems,
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
    return TrophyListState(
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
