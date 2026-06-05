import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Tela para cadastrar/atualizar a foto 3x4 privada usada no reconhecimento facial.
/// Não é visível a outros alunos.
class UserFacialPhotoScreen extends StatefulWidget {
  const UserFacialPhotoScreen({super.key});

  @override
  State<UserFacialPhotoScreen> createState() => _UserFacialPhotoScreenState();
}

class _UserFacialPhotoScreenState extends State<UserFacialPhotoScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();

  XFile? _photo;
  Uint8List? _photoBytes;
  bool _sending = false;

  Future<void> _pickFromCamera() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1200,
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
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
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
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    final bytes = _photoBytes;
    if (_sending || photo == null || bytes == null) return;
    setState(() => _sending = true);
    try {
      await _api.uploadMyFacialPhoto(
        bytes: bytes,
        filename: photo.name,
        contentType: photo.mimeType,
      );
      await AuthService().refreshMe();
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Foto de reconhecimento facial atualizada.',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFacialPhoto =
        AuthService().currentUser?.facialPhotoUrl != null &&
            AuthService().currentUser!.facialPhotoUrl!.isNotEmpty;
    final screen = MediaQuery.sizeOf(context);
    final previewMaxW = screen.width.clamp(200.0, 320.0);

    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Foto de reconhecimento facial'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Esta foto é privada e usada apenas para o reconhecimento facial na chamada. '
            'Não é visível para outros alunos.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Dicas para uma boa foto:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('• Rosto centralizado e completamente visível'),
                Text('• Boa iluminação — evite sombras no rosto'),
                Text('• Fundo neutro (parede ou tatame)'),
                Text('• Sem óculos escuros ou máscara'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (hasFacialPhoto && _photoBytes == null)
            Align(
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    'Foto de reconhecimento já cadastrada.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          if (_photoBytes != null) ...[
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: previewMaxW),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photoBytes!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : _pickFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Câmera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeria'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: (_sending || _photoBytes == null) ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Enviar foto'),
          ),
        ],
      ),
    );
  }
}
