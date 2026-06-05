import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:viewer/features/photos/presentation/state/photos_feed_state.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_di.dart';
import 'package:viewer/models/academy_photo.dart';

class PhotosFeedNotifier
    extends AutoDisposeFamilyNotifier<PhotosFeedState, String> {
  static final _log = Logger('PhotosFeedNotifier');

  Timer? _pollingTimer;

  // Retorna true se há fotos de usuário ainda em processamento
  bool get _hasPendingPhotos =>
      state.items.any((p) => !p.isSystemPost && !p.isReady);

  @override
  PhotosFeedState build(String academyId) {
    // Garante que o timer é cancelado quando o provider é descartado
    ref.onDispose(_stopPolling);
    Future.microtask(_bootstrap);
    return PhotosFeedState(academyId: academyId);
  }

  Future<void> _bootstrap() async {
    final api = ref.read(apiServiceProvider);
    try {
      final page = await api.getPhotosFeed(state.academyId);
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        isInitialLoading: false,
        clearError: true,
      );
      // Inicia polling se carregou fotos ainda em processamento
      _startPollingIfNeeded();
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
      final page = await api.getPhotosFeed(state.academyId);
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        isRefreshing: false,
        clearError: true,
      );
      _startPollingIfNeeded();
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
        state.academyId,
        cursor: state.nextCursor,
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

  /// Adiciona a foto no topo do feed e inicia polling automático
  /// caso a foto ainda não esteja pronta (status != 'ready').
  void prependPhoto(AcademyPhoto photo) {
    state = state.copyWith(items: [photo, ...state.items]);
    _startPollingIfNeeded();
  }

  // ─── Polling silencioso ───────────────────────────────────────────────────

  void _startPollingIfNeeded() {
    if (_pollingTimer?.isActive == true) return; // já rodando
    if (!_hasPendingPhotos) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_hasPendingPhotos) {
        _stopPolling();
        return;
      }
      _silentRefreshPending();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Busca o feed e atualiza silenciosamente apenas os itens cujo status mudou.
  /// Não altera flags de loading para não mostrar nenhum indicador ao usuário.
  Future<void> _silentRefreshPending() async {
    try {
      final api = ref.read(apiServiceProvider);
      final page = await api.getPhotosFeed(state.academyId);

      final feedMap = {for (final p in page.items) p.id: p};
      bool changed = false;

      final updated = state.items.map((p) {
        final fresh = feedMap[p.id];
        if (fresh != null && fresh.status != p.status) {
          changed = true;
          return fresh;
        }
        return p;
      }).toList();

      if (changed) {
        state = state.copyWith(items: updated);
        _log.fine('Fotos pendentes atualizadas silenciosamente');
      }

      // Para o timer se não restam pendentes após a atualização
      if (!_hasPendingPhotos) _stopPolling();
    } catch (e) {
      _log.fine('silentRefreshPending ignorado: $e');
    }
  }

  // ─── Like / Unlike / Delete ───────────────────────────────────────────────

  Future<void> likeOptimistic(AcademyPhoto photo) async {
    _updatePhotoInList(
      photo.id,
      (p) => p.copyWith(likesCount: p.likesCount + 1, likedByMe: true),
    );
    final api = ref.read(apiServiceProvider);
    try {
      await api.likePhoto(state.academyId, photo.id);
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
      await api.unlikePhoto(state.academyId, photo.id);
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
      await api.deletePhoto(state.academyId, photoId);
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
