import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/core/leveling.dart';
import 'package:viewer/features/photos/presentation/providers/photos_providers.dart';
import 'package:viewer/features/photos/presentation/widgets/post_card.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

// ---------------------------------------------------------------------------
// Header do perfil do aluno
// ---------------------------------------------------------------------------

class _StudentProfileHeader extends StatefulWidget {
  const _StudentProfileHeader({
    required this.academyId,
    required this.studentId,
    required this.studentName,
    required this.avatarUrl,
    required this.photoCount,
    required this.totalLikes,
  });

  final String academyId;
  final String studentId;
  final String studentName;
  final String avatarUrl;
  final int photoCount;
  final int totalLikes;

  @override
  State<_StudentProfileHeader> createState() => _StudentProfileHeaderState();
}

class _StudentProfileHeaderState extends State<_StudentProfileHeader> {
  final _api = ApiService();
  String? _graduation;
  String? _loadedAvatarUrl;
  int? _level;
  List<TrophyWithEarned> _trophies = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getTrophiesForUser(widget.studentId),
        _api.getUserPoints(widget.studentId),
      ]);
      if (!mounted) return;
      final points = results[1] as Map<String, dynamic>;
      setState(() {
        _graduation = points['graduation'] as String?;
        _loadedAvatarUrl = points['avatar_url'] as String?;
        _trophies = (results[0] as List<TrophyWithEarned>)
            .where((t) => t.earnedTier != null)
            .toList();
        _level = levelProgressFromUserPointsMap(points).level;
      });
    } catch (_) {}
  }

  static const Map<String, String> _beltLabels = {
    'white': 'Branca',
    'blue': 'Azul',
    'purple': 'Roxa',
    'brown': 'Marrom',
    'black': 'Preta',
  };

  static const Map<String, Color> _beltColors = {
    'white': Color(0xFFEEEEEE),
    'blue': Color(0xFF1565C0),
    'purple': Color(0xFF6A1B9A),
    'brown': Color(0xFF4E342E),
    'black': Color(0xFF212121),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final name = widget.studentName.isNotEmpty ? widget.studentName : 'Aluno';
    final resolvedAvatarUrl =
        (_loadedAvatarUrl?.isNotEmpty == true) ? _loadedAvatarUrl! : widget.avatarUrl;
    final graduation = (_graduation ?? '').toLowerCase();
    final beltLabel = _beltLabels[graduation] ?? graduation;
    final beltColor = _beltColors[graduation] ?? Colors.grey;
    final baseUrl = _api.baseUrl;
    final fullAvatarUrl = resolvedAvatarUrl.startsWith('/')
        ? '$baseUrl$resolvedAvatarUrl'
        : resolvedAvatarUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + nome + faixa
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: cs.primaryContainer,
                backgroundImage: fullAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(fullAvatarUrl)
                    : null,
                child: fullAvatarUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (graduation.isNotEmpty || _level != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (graduation.isNotEmpty) ...[
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: beltColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cs.outline.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Faixa $beltLabel',
                              style: tt.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                          if (graduation.isNotEmpty && _level != null)
                            const SizedBox(width: 12),
                          if (_level != null) ...[
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: const Color(0xFFFFC107),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Nível $_level',
                              style: tt.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Stats: fotos
                    _StatChip(
                      icon: Icons.photo_library_outlined,
                      label: '${widget.photoCount} foto${widget.photoCount != 1 ? 's' : ''}',
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Troféus e medalhas conquistados
          if (_trophies.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Conquistas',
                style: tt.labelSmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _trophies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final t = _trophies[i];
                  final emoji = TrophyWithEarned.tierEmoji(t.earnedTier);
                  final isTrophy = t.awardKind == 'trophy';
                  return Tooltip(
                    message: '${t.name} · ${t.tierLabel}',
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 3),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isTrophy ? '🏆$emoji' : emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(color: cs.outline.withValues(alpha: 0.2), height: 1),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feed de fotos do aluno
// ---------------------------------------------------------------------------

/// Aba "Fotos" do perfil do aluno — exibe somente os posts desse aluno
/// no feed da academia. Reutiliza o mesmo PostCard do feed geral.
class StudentPhotosFeedScreen extends ConsumerWidget {
  const StudentPhotosFeedScreen({
    super.key,
    required this.academyId,
    required this.studentId,
    this.studentName = '',
    this.avatarUrl = '',
  });

  final String academyId;
  final String studentId;
  final String studentName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '$academyId|$studentId';
    final state = ref.watch(photosUserFeedNotifierProvider(key));
    final notifier = ref.read(photosUserFeedNotifierProvider(key).notifier);

    final currentUser = AuthService().currentUser;
    final currentUserId = currentUser?.id ?? '';
    final role = (currentUser?.role ?? '').trim().toLowerCase();
    final isModerator =
        role == 'administrador' || role == 'gerente_academia';

    // Stats calculadas do feed carregado
    final photoCount = state.items.length;
    final totalLikes =
        state.items.fold<int>(0, (sum, p) => sum + p.likesCount);

    if (state.isInitialLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: notifier.refresh,
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
            // Header do perfil
            SliverToBoxAdapter(
              child: _StudentProfileHeader(
                academyId: academyId,
                studentId: studentId,
                studentName: studentName,
                avatarUrl: avatarUrl,
                photoCount: photoCount,
                totalLikes: totalLikes,
              ),
            ),

            // Estado vazio
            if (state.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma foto publicada ainda.',
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
                  4,
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
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            : const SizedBox.shrink();
                      }
                      final photo = state.items[i];
                      return PostCard(
                        key: ValueKey(photo.id),
                        photo: photo,
                        academyId: academyId,
                        currentUserId: currentUserId,
                        isModerator: isModerator,
                        onLike: () => notifier.likeOptimistic(photo),
                        onUnlike: () => notifier.unlikeOptimistic(photo),
                        onDelete: () async {
                          await notifier.deleteOptimistic(photo.id);
                        },
                        onShare: null,
                      );
                    },
                    childCount: state.items.length + (state.hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wrapper com Scaffold + AppBar
// ---------------------------------------------------------------------------

/// Wrapper com Scaffold + AppBar para exibir o feed de fotos de um aluno
/// ao navegar a partir da lista de usuários ou do feed geral.
class StudentPhotosFeedPage extends StatelessWidget {
  const StudentPhotosFeedPage({
    super.key,
    required this.academyId,
    required this.studentId,
    required this.studentName,
  });

  final String academyId;
  final String studentId;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Fotos',
        subtitle: studentName,
      ),
      body: StudentPhotosFeedScreen(
        academyId: academyId,
        studentId: studentId,
        studentName: studentName,
      ),
    );
  }
}
