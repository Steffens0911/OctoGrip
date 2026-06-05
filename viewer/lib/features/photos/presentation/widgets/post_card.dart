import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:viewer/features/photos/presentation/pages/photo_detail_screen.dart';
import 'package:viewer/features/photos/presentation/pages/student_photos_feed_screen.dart';
import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/services/api_service.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.photo,
    required this.academyId,
    required this.currentUserId,
    required this.isModerator,
    required this.onLike,
    required this.onUnlike,
    required this.onDelete,
    this.onShare,
  });

  final AcademyPhoto photo;
  final String academyId;
  final String currentUserId;
  final bool isModerator;
  final VoidCallback onLike;
  final VoidCallback onUnlike;
  final VoidCallback onDelete;
  final VoidCallback? onShare;

  bool get _canDelete =>
      photo.author.id == currentUserId || isModerator;

  String _absoluteUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final base = ApiService().baseUrl;
    return raw.startsWith('/') ? '$base$raw' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PostHeader(
            photo: photo,
            absoluteUrl: _absoluteUrl,
            canDelete: _canDelete,
            onDelete: onDelete,
          ),
          if (photo.isSystemPost)
            _SystemPostBody(photo: photo, cs: cs, tt: tt)
          else
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoDetailScreen(
                    photo: photo,
                    academyId: academyId,
                    currentUserId: currentUserId,
                    isModerator: isModerator,
                    onLike: onLike,
                    onUnlike: onUnlike,
                    onDelete: onDelete,
                  ),
                ),
              ),
              child: _PhotoBody(
                  absoluteUrl: _absoluteUrl(photo.thumbnailUrl).isNotEmpty
                      ? _absoluteUrl(photo.thumbnailUrl)
                      : _absoluteUrl(photo.imageUrl)),
            ),
          if (photo.caption != null && photo.caption!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(photo.caption!, style: tt.bodyMedium),
            ),
          _LikeRow(
            photo: photo,
            cs: cs,
            academyId: academyId,
            currentUserId: currentUserId,
            isModerator: isModerator,
            onLike: onLike,
            onUnlike: onUnlike,
            onDelete: onDelete,
            onShare: onShare,
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.photo,
    required this.absoluteUrl,
    required this.canDelete,
    required this.onDelete,
  });

  final AcademyPhoto photo;
  final String Function(String?) absoluteUrl;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final authorAvatar = absoluteUrl(photo.author.avatarUrl);
    final displayName = photo.author.name ?? 'Aluno';
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(
      photo.createdAt.toLocal(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openAuthorFeed(context),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: authorAvatar.isNotEmpty
              ? CachedNetworkImageProvider(authorAvatar)
              : null,
          child: authorAvatar.isEmpty
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showMenu(context),
        ),
      ),
    );
  }

  void _openAuthorFeed(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => StudentPhotosFeedPage(
          academyId: photo.academyId,
          studentId: photo.author.id,
          studentName: photo.author.name ?? 'Aluno',
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Ver fotos de ${photo.author.name ?? 'aluno'}'),
              onTap: () {
                Navigator.pop(ctx);
                _openAuthorFeed(context);
              },
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Excluir post',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir post'),
        content: const Text('Deseja remover este post do feed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) onDelete();
    });
  }
}

class _PhotoBody extends StatelessWidget {
  const _PhotoBody({required this.absoluteUrl});

  final String absoluteUrl;

  @override
  Widget build(BuildContext context) {
    if (absoluteUrl.isEmpty) {
      return Container(
        height: 200,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Processando...',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CachedNetworkImage(
        imageUrl: absoluteUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.errorContainer,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}

class _SystemPostBody extends StatelessWidget {
  const _SystemPostBody({
    required this.photo,
    required this.cs,
    required this.tt,
  });

  final AcademyPhoto photo;
  final ColorScheme cs;
  final TextTheme tt;

  IconData get _icon {
    return switch (photo.systemPostType) {
      'trophy' => Icons.emoji_events_rounded,
      'belt_promotion' => Icons.military_tech_rounded,
      _ => Icons.star_rounded,
    };
  }

  Color get _iconColor {
    return switch (photo.systemPostType) {
      'trophy' => const Color(0xFFD4A017),
      'belt_promotion' => const Color(0xFF4ecf8a),
      _ => const Color(0xFFD4A017),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, size: 48, color: _iconColor),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              photo.caption ?? '',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeRow extends StatelessWidget {
  const _LikeRow({
    required this.photo,
    required this.cs,
    required this.academyId,
    required this.currentUserId,
    required this.isModerator,
    required this.onLike,
    required this.onUnlike,
    this.onShare,
    this.onDelete,
  });

  final AcademyPhoto photo;
  final ColorScheme cs;
  final String academyId;
  final String currentUserId;
  final bool isModerator;
  final VoidCallback onLike;
  final VoidCallback onUnlike;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              photo.likedByMe ? Icons.favorite_rounded : Icons.favorite_border,
              color: photo.likedByMe ? Colors.red : cs.onSurfaceVariant,
            ),
            onPressed: photo.likedByMe ? onUnlike : onLike,
            tooltip: photo.likedByMe ? 'Descurtir' : 'Curtir',
          ),
          if (photo.likesCount > 0)
            Text(
              '${photo.likesCount}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, size: 22, color: cs.onSurfaceVariant),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoDetailScreen(
                  photo: photo,
                  academyId: academyId,
                  currentUserId: currentUserId,
                  isModerator: isModerator,
                  onLike: onLike,
                  onUnlike: onUnlike,
                  onDelete: onDelete ?? () {},
                ),
              ),
            ),
            tooltip: 'Comentários',
          ),
          if (photo.commentsCount > 0)
            Text(
              '${photo.commentsCount}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          const Spacer(),
          // Botão de compartilhar — aparece só para fotos prontas (com imagem)
          if (onShare != null && photo.isReady && !photo.isSystemPost)
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: onShare,
              tooltip: 'Compartilhar',
            ),
        ],
      ),
    );
  }
}
