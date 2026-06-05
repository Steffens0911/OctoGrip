import 'package:viewer/models/academy_photo.dart';

class PhotosFeedState {
  const PhotosFeedState({
    required this.academyId,
    this.items = const [],
    this.nextCursor,
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.mutationInProgress = false,
  });

  final String academyId;
  final List<AcademyPhoto> items;
  final String? nextCursor;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? errorMessage;
  final bool mutationInProgress;

  bool get hasMore => nextCursor != null;

  PhotosFeedState copyWith({
    List<AcademyPhoto>? items,
    Object? nextCursor = _sentinel,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    bool? mutationInProgress,
  }) {
    return PhotosFeedState(
      academyId: academyId,
      items: items ?? this.items,
      nextCursor: nextCursor == _sentinel
          ? this.nextCursor
          : nextCursor as String?,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mutationInProgress: mutationInProgress ?? this.mutationInProgress,
    );
  }
}

const _sentinel = Object();
