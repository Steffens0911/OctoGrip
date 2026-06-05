import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/photos/presentation/state/photos_feed_state.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_di.dart';
import 'package:viewer/models/academy_photo.dart';

/// Feed de fotos filtrado por autor — usado na aba "Fotos" do perfil do aluno.
/// Recebe a key no formato "academyId|authorId".
class PhotosUserFeedNotifier
    extends AutoDisposeFamilyNotifier<PhotosFeedState, String> {
  static final _log = Logger('PhotosUserFeedNotifier');

  String get _academyId => arg.split('|')[0];
  String get _authorId => arg.split('|')[1];

  @override
  PhotosFeedState build(String key) {
    Future.microtask(_bootstrap);
    return PhotosFeedState(academyId: _academyId);
  }

  Future<void> _bootstrap() async {
    final api = ref.read(apiServiceProvider);
    try {
      final page = await api.getPhotosFeed(
        _academyId,
        authorId: _authorId,
      );
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        isInitialLoading: false,
        clearError: true,
      );
    } catch (e) {
      _log.warning('bootstrap failed: $e');
      state = state.copyWith(
        isInitialLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    final api = ref.read(apiServiceProvider);
    try {
      final page = await api.getPhotosFeed(
        _academyId,
        authorId: _authorId,
      );
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        isRefreshing: false,
        clearError: true,
      );
    } catch (e) {
      _log.warning('refresh failed: $e');
      state = state.copyWith(isRefreshing: false, errorMessage: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    final api = ref.read(apiServiceProvider);
    try {
      final page = await api.getPhotosFeed(
        _academyId,
        cursor: state.nextCursor,
        authorId: _authorId,
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        isLoadingMore: false,
      );
    } catch (e) {
      _log.warning('loadMore failed: $e');
      state = state.copyWith(isLoadingMore: false, errorMessage: e.toString());
    }
  }

  Future<void> likeOptimistic(AcademyPhoto photo) async {
    _updatePhotoInList(
      photo.id,
      (p) => p.copyWith(likesCount: p.likesCount + 1, likedByMe: true),
    );
    final api = ref.read(apiServiceProvider);
    try {
      await api.likePhoto(_academyId, photo.id);
    } catch (e) {
      _log.warning('likePhoto failed: $e');
      _updatePhotoInList(
        photo.id,
        (p) => p.copyWith(likesCount: p.likesCount - 1, likedByMe: false),
      );
    }
  }

  Future<void> unlikeOptimistic(AcademyPhoto photo) async {
    _updatePhotoInList(
      photo.id,
      (p) => p.copyWith(
        likesCount: (p.likesCount - 1).clamp(0, 999999),
        likedByMe: false,
      ),
    );
    final api = ref.read(apiServiceProvider);
    try {
      await api.unlikePhoto(_academyId, photo.id);
    } catch (e) {
      _log.warning('unlikePhoto failed: $e');
      _updatePhotoInList(
        photo.id,
        (p) => p.copyWith(likesCount: p.likesCount + 1, likedByMe: true),
      );
    }
  }

  Future<void> deleteOptimistic(String photoId) async {
    if (state.mutationInProgress) return;
    state = state.copyWith(mutationInProgress: true, clearError: true);
    final api = ref.read(apiServiceProvider);
    try {
      await api.deletePhoto(_academyId, photoId);
      final updated = state.items.where((p) => p.id != photoId).toList();
      state = state.copyWith(items: updated, mutationInProgress: false);
    } catch (e) {
      _log.warning('deletePhoto failed: $e');
      state = state.copyWith(
        mutationInProgress: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _updatePhotoInList(
    String photoId,
    AcademyPhoto Function(AcademyPhoto) transform,
  ) {
    final updated = state.items.map((p) {
      return p.id == photoId ? transform(p) : p;
    }).toList();
    state = state.copyWith(items: updated);
  }
}
