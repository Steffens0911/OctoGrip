import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/photos/presentation/pages/new_post_screen.dart';
import 'package:viewer/features/photos/presentation/providers/photos_providers.dart';
import 'package:viewer/features/photos/presentation/widgets/post_card.dart';
import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/app_feedback.dart';

class PhotosFeedScreen extends ConsumerStatefulWidget {
  const PhotosFeedScreen({super.key, required this.academyId});

  final String academyId;

  @override
  ConsumerState<PhotosFeedScreen> createState() => _PhotosFeedScreenState();
}

class _PhotosFeedScreenState extends ConsumerState<PhotosFeedScreen> {
  Future<void> _openNewPost() async {
    await Navigator.push<AcademyPhoto?>(
      context,
      MaterialPageRoute(
        builder: (_) => NewPostScreen(academyId: widget.academyId),
      ),
    );
  }

  String _absoluteUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final base = ApiService().baseUrl;
    return raw.startsWith('/') ? '$base$raw' : raw;
  }

  Future<void> _sharePhoto(AcademyPhoto photo) async {
    final imageUrl = _absoluteUrl(photo.imageUrl ?? photo.thumbnailUrl);
    if (imageUrl.isEmpty) return;

    // Web e nativo usam o mesmo caminho: baixa a imagem e aciona o share sheet nativo.
    // No browser, o Web Share API com arquivo requer HTTPS — em produção funciona automaticamente.
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

      final xfile = XFile.fromData(
        response.bodyBytes,
        mimeType: 'image/jpeg',
        name: 'octogrip_${photo.id}.jpg',
      );

      await Share.shareXFiles(
        [xfile],
        text: photo.caption ?? '',
      );
    } catch (e) {
      if (!mounted) return;
      final msg = kIsWeb
          ? 'Compartilhamento requer conexão segura (HTTPS).'
          : 'Não foi possível compartilhar a foto.';
      AppFeedback.show(
        context,
        message: msg,
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _deletePhoto(AcademyPhoto photo) async {
    await ref
        .read(photosFeedNotifierProvider(widget.academyId).notifier)
        .deleteOptimistic(photo.id);

    if (!mounted) return;
    final err =
        ref.read(photosFeedNotifierProvider(widget.academyId)).errorMessage;
    if (err != null) {
      AppFeedback.show(
        context,
        message: err,
        type: AppFeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(photosFeedNotifierProvider(widget.academyId));
    final notifier =
        ref.read(photosFeedNotifierProvider(widget.academyId).notifier);

    final currentUser = AuthService().currentUser;
    final currentUserId = currentUser?.id ?? '';
    final role = (currentUser?.role ?? '').trim().toLowerCase();
    final isModerator =
        role == 'administrador' || role == 'gerente_academia';

    Widget body;

    if (state.isInitialLoading) {
      body = Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    } else if (state.errorMessage != null && state.items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: notifier.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh:
            state.mutationInProgress ? () async {} : notifier.refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent * 0.85) {
              notifier.loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (state.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library,
                          size: 64,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum post ainda.\nSeja o primeiro a compartilhar!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.screenPadding(context),
                    8,
                    AppTheme.screenPadding(context),
                    80,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i == state.items.length) {
                          return state.hasMore
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                )
                              : const SizedBox.shrink();
                        }
                        final photo = state.items[i];
                        return PostCard(
                          key: ValueKey(photo.id),
                          photo: photo,
                          academyId: widget.academyId,
                          currentUserId: currentUserId,
                          isModerator: isModerator,
                          onLike: () => notifier.likeOptimistic(photo),
                          onUnlike: () =>
                              notifier.unlikeOptimistic(photo),
                          onDelete: () => _deletePhoto(photo),
                          onShare: () => _sharePhoto(photo),
                        );
                      },
                      childCount: state.items.length +
                          (state.hasMore ? 1 : 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: currentUser?.accountFrozen == true
          ? null
          : FloatingActionButton(
              onPressed: _openNewPost,
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
            ),
    );
  }
}
