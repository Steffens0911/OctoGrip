import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class UserAvatarScreen extends StatefulWidget {
  const UserAvatarScreen({super.key});

  @override
  State<UserAvatarScreen> createState() => _UserAvatarScreenState();
}

class _UserAvatarScreenState extends State<UserAvatarScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();

  XFile? _photo;
  Uint8List? _photoBytes;
  String? _avatarUrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = AuthService().currentUser?.avatarUrl;
  }

  String? _absoluteMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return rawUrl.startsWith('/') ? '${_api.baseUrl}$rawUrl' : rawUrl;
  }

  Future<void> _pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _photoBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    final bytes = _photoBytes;
    if (_sending || photo == null || bytes == null) return;
    setState(() => _sending = true);
    try {
      final updated = await _api.uploadMyAvatar(
        bytes: bytes,
        filename: photo.name,
        contentType: photo.mimeType,
      );
      await AuthService().refreshMe();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _avatarUrl = updated.avatarUrl;
      });
      AppFeedback.show(
        context,
        message: 'Foto de perfil atualizada.',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = _absoluteMediaUrl(_avatarUrl);
    final screen = MediaQuery.sizeOf(context);
    final previewMaxW = screen.width.clamp(240.0, 420.0);
    return Scaffold(
      appBar: const AppStandardAppBar(
        title: 'Foto de perfil',
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Sua foto será usada no reconhecimento facial da chamada.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (currentUrl != null)
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: previewMaxW),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    child: Image.network(
                      currentUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          if (currentUrl == null)
            const Text('Você ainda não tem foto cadastrada.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _sending ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
                _photo == null ? 'Selecionar foto' : 'Trocar foto selecionada'),
          ),
          const SizedBox(height: 12),
          if (_photoBytes != null)
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: previewMaxW),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    child: Image.memory(
                      _photoBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (_sending || _photoBytes == null) ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Enviar foto'),
          ),
        ],
      ),
    );
  }
}
