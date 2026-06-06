import 'package:flutter/material.dart';

import 'package:viewer/features/photos/presentation/pages/photo_detail_screen.dart';
import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

/// Tela intermediária para navegar para uma foto a partir de uma notificação.
/// Recebe apenas os IDs, busca a foto na API e abre o PhotoDetailScreen.
class PhotoFromNotificationScreen extends StatefulWidget {
  const PhotoFromNotificationScreen({
    super.key,
    required this.academyId,
    required this.photoId,
  });

  final String academyId;
  final String photoId;

  @override
  State<PhotoFromNotificationScreen> createState() =>
      _PhotoFromNotificationScreenState();
}

class _PhotoFromNotificationScreenState
    extends State<PhotoFromNotificationScreen> {
  AcademyPhoto? _photo;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final photo =
          await ApiService().getPhotoById(widget.academyId, widget.photoId);
      if (mounted) {
        setState(() {
          _photo = photo;
          _notFound = photo == null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foto')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_notFound || _photo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foto')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Esta foto não está mais disponível.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final photo = _photo!;
    final currentUser = AuthService().currentUser;
    final currentUserId = currentUser?.id ?? '';
    final role = (currentUser?.role ?? '').trim().toLowerCase();
    final isModerator =
        role == 'administrador' || role == 'gerente_academia';

    return PhotoDetailScreen(
      photo: photo,
      academyId: widget.academyId,
      currentUserId: currentUserId,
      isModerator: isModerator,
      onLike: () async {
        try {
          await ApiService().likePhoto(widget.academyId, photo.id);
        } catch (_) {}
      },
      onUnlike: () async {
        try {
          await ApiService().unlikePhoto(widget.academyId, photo.id);
        } catch (_) {}
      },
      onDelete: () => Navigator.pop(context),
    );
  }
}
