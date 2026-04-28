import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class FaceRecognitionCheckinScreen extends StatefulWidget {
  final String sessionId;

  const FaceRecognitionCheckinScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<FaceRecognitionCheckinScreen> createState() =>
      _FaceRecognitionCheckinScreenState();
}

class _FaceRecognitionCheckinScreenState
    extends State<FaceRecognitionCheckinScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();

  XFile? _photo;
  Uint8List? _photoBytes;
  bool _sending = false;

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
    final bytes = _photoBytes;
    final photo = _photo;
    if (bytes == null || photo == null || _sending) return;
    setState(() => _sending = true);
    try {
      final response = await _api.submitFaceRecognitionPhoto(
        sessionId: widget.sessionId,
        bytes: bytes,
        filename: photo.name,
        contentType: photo.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
      });
      AppFeedback.show(
        context,
        message: 'Foto enviada para processamento.',
        type: AppFeedbackType.success,
      );
      Navigator.of(context).pop(response);
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
    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Chamada por foto'),
      body: ListView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        children: [
          Text(
            'Selecione uma foto da turma já tirada na galeria.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _sending ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
                _photo == null ? 'Selecionar foto da turma' : 'Trocar foto'),
          ),
          const SizedBox(height: 12),
          if (_photoBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _photoBytes!,
                fit: BoxFit.cover,
                height: 220,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'O processamento leva alguns instantes. Você receberá uma notificação quando terminar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_photoBytes == null || _sending) ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_sending ? 'Enviando...' : 'Enviar para processamento'),
          ),
        ],
      ),
    );
  }
}
