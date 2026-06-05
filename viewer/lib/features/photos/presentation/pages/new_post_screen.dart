import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:viewer/features/photos/presentation/providers/photos_providers.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';

class NewPostScreen extends ConsumerStatefulWidget {
  const NewPostScreen({super.key, required this.academyId});

  final String academyId;

  @override
  ConsumerState<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends ConsumerState<NewPostScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _selectedFile;
  Uint8List? _previewBytes;
  bool _uploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// Abre a galeria e, em seguida, o cropper. Só atualiza o estado se o
  /// usuário confirmar o recorte — cancelar qualquer etapa não altera nada.
  Future<void> _pickAndCrop() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2048,
      );
      if (file == null) return;

      if (!mounted) return;
      await _cropImage(file);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  /// Abre o cropper para o arquivo informado.
  /// Retorna sem alterar o estado se o usuário cancelar.
  Future<void> _cropImage(XFile file) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      // Trava a proporção 4:3 em todas as plataformas
      aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        WebUiSettings(
          context: context,
          size: const CropperSize(width: 480, height: 340),
          viewwMode: WebViewMode.mode_1,
          translations: const WebTranslations(
            title: 'Recortar foto (4:3)',
            rotateLeftTooltip: 'Girar à esquerda',
            rotateRightTooltip: 'Girar à direita',
            cropButton: 'Confirmar',
            cancelButton: 'Cancelar',
          ),
        ),
        AndroidUiSettings(
          toolbarTitle: 'Recortar foto',
          toolbarColor: const Color(0xFF1A1A2E),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio4x3,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar foto',
          cancelButtonTitle: 'Cancelar',
          doneButtonTitle: 'Confirmar',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    // Usuário cancelou o crop — não altera nada
    if (croppedFile == null) return;

    final bytes = await croppedFile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _previewBytes = bytes;
    });
  }

  MediaType _mediaType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  Future<void> _submit() async {
    final file = _selectedFile;
    final bytes = _previewBytes;
    if (file == null || bytes == null || _uploading) return;

    final caption = _captionController.text.trim();
    if (caption.length > 280) {
      AppFeedback.show(
        context,
        message: 'Legenda muito longa (máximo 280 caracteres).',
        type: AppFeedbackType.warning,
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final photo = await ApiService().createPhoto(
        widget.academyId,
        bytes: bytes,
        filename: file.name,
        contentType: _mediaType(file.name),
        caption: caption.isNotEmpty ? caption : null,
      );
      if (!mounted) return;
      ref
          .read(photosFeedNotifierProvider(widget.academyId).notifier)
          .prependPhoto(photo);
      Navigator.pop(context, photo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      AppFeedback.show(
        context,
        message: userFacingMessage(e),
        type: AppFeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo post'),
        actions: [
          if (_selectedFile != null)
            _uploading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _submit,
                    child: const Text('Publicar'),
                  ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Área de preview / seleção de foto — proporção 4:3 igual ao feed
            GestureDetector(
              onTap: _uploading ? null : _pickAndCrop,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _previewBytes != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_previewBytes!, fit: BoxFit.cover),
                          // Botão de re-recorte sobreposto no canto
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _uploading
                                ? const SizedBox.shrink()
                                : Material(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => _cropImage(_selectedFile!),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.crop, size: 16, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'Recortar',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toque para selecionar e recortar uma foto',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                ),  // Container
              ),    // AspectRatio
            ),      // GestureDetector
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              maxLength: 280,
              maxLines: 4,
              minLines: 2,
              enabled: !_uploading,
              decoration: const InputDecoration(
                hintText: 'Adicione uma legenda... (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedFile == null)
              FilledButton.icon(
                onPressed: _pickAndCrop,
                icon: const Icon(Icons.photo_library),
                label: const Text('Escolher foto'),
              )
            else
              FilledButton.icon(
                onPressed: _uploading ? null : _submit,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_uploading ? 'Enviando...' : 'Publicar'),
              ),
          ],
        ),
      ),
    );
  }
}
