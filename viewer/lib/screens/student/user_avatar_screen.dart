import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viewer/design/app_tokens.dart';
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

  // --- foto de perfil ---
  XFile? _avatarPhoto;
  Uint8List? _avatarBytes;
  String? _avatarUrl;
  int _avatarCacheBust = 0;
  bool _sendingAvatar = false;

  // --- foto facial ---
  XFile? _facialPhoto;
  Uint8List? _facialBytes;
  bool _sendingFacial = false;
  bool _facialSaved = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _avatarUrl = user?.avatarUrl;
    _facialSaved = user?.facialPhotoUrl != null && user!.facialPhotoUrl!.isNotEmpty;
  }

  String? _absoluteMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return rawUrl.startsWith('/') ? '${_api.baseUrl}$rawUrl' : rawUrl;
  }

  Future<void> _pickAvatar() async {
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
        _avatarPhoto = photo;
        _avatarBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _submitAvatar() async {
    final photo = _avatarPhoto;
    final bytes = _avatarBytes;
    if (_sendingAvatar || photo == null || bytes == null) return;
    setState(() => _sendingAvatar = true);
    try {
      final updated = await _api.uploadMyAvatar(
        bytes: bytes,
        filename: photo.name,
        contentType: photo.mimeType,
      );
      await AuthService().refreshMe();
      if (!mounted) return;
      final newUrl = updated.avatarUrl;
      if (newUrl != null) {
        await CachedNetworkImage.evictFromCache(
            newUrl.startsWith('/') ? '${_api.baseUrl}$newUrl' : newUrl);
      }
      if (!mounted) return;
      setState(() {
        _sendingAvatar = false;
        _avatarUrl = newUrl;
        _avatarCacheBust = DateTime.now().millisecondsSinceEpoch;
        _avatarPhoto = null;
        _avatarBytes = null;
      });
      AppFeedback.show(context, message: 'Foto de perfil atualizada.', type: AppFeedbackType.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingAvatar = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _pickFacial() async {
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
        _facialPhoto = photo;
        _facialBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  Future<void> _submitFacial() async {
    final photo = _facialPhoto;
    final bytes = _facialBytes;
    if (_sendingFacial || photo == null || bytes == null) return;
    setState(() => _sendingFacial = true);
    try {
      await _api.uploadMyFacialPhoto(
        bytes: bytes,
        filename: photo.name,
        contentType: photo.mimeType,
      );
      await AuthService().refreshMe();
      if (!mounted) return;
      setState(() {
        _sendingFacial = false;
        _facialSaved = true;
        _facialPhoto = null;
        _facialBytes = null;
      });
      AppFeedback.show(
        context,
        message: 'Foto de reconhecimento facial salva.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingFacial = false);
      AppFeedback.show(context, message: userFacingMessage(e), type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = _absoluteMediaUrl(_avatarUrl);
    final screen = MediaQuery.sizeOf(context);
    final previewMaxW = screen.width.clamp(240.0, 420.0);
    final facialPreviewMaxW = screen.width.clamp(160.0, 280.0);
    final dividerColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);

    // Adiciona cache-bust à URL para forçar reload após upload
    final displayUrl = currentUrl != null && _avatarCacheBust > 0
        ? '$currentUrl?t=$_avatarCacheBust'
        : currentUrl;

    return Scaffold(
      appBar: const AppStandardAppBar(title: 'Fotos'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── SEÇÃO: foto de perfil ─────────────────────────────────────────
          Text(
            'Foto de perfil',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          AppSpacing.verticalS,
          Text(
            'Aparece no seu perfil e é visível para colegas da academia.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          // Mostra preview da nova foto selecionada OU a foto atual salva
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: previewMaxW),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  child: _avatarBytes != null
                      ? Image.memory(
                          _avatarBytes!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          filterQuality: FilterQuality.high,
                        )
                      : displayUrl != null
                          ? CachedNetworkImage(
                              imageUrl: displayUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              placeholder: (_, __) =>
                                  const Center(child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.person, size: 48),
                              filterQuality: FilterQuality.high,
                            )
                          : const SizedBox(
                              height: 120,
                              child: Center(child: Icon(Icons.person, size: 48)),
                            ),
                ),
              ),
            ),
          ),
          if (currentUrl == null && _avatarBytes == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Você ainda não tem foto de perfil cadastrada.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _sendingAvatar ? null : _pickAvatar,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_avatarPhoto == null ? 'Selecionar foto' : 'Trocar foto selecionada'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: (_sendingAvatar || _avatarBytes == null) ? null : _submitAvatar,
            icon: _sendingAvatar
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Salvar foto de perfil'),
          ),

          // ── DIVISOR ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Divider(color: dividerColor),
          ),

          // ── SEÇÃO: foto facial ────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Foto para reconhecimento facial',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Privada',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.verticalS,
          Text(
            'Usada apenas para identificação na chamada. Não é exibida para ninguém.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dicas:', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('• Rosto centralizado e bem iluminado',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('• Fundo neutro, sem óculos escuros',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_facialSaved && _facialBytes == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text('Foto facial já cadastrada.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          if (_facialBytes != null) ...[
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: facialPreviewMaxW),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _facialBytes!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            onPressed: _sendingFacial ? null : _pickFacial,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_facialPhoto == null
                ? (_facialSaved ? 'Trocar foto facial' : 'Selecionar foto facial')
                : 'Trocar foto selecionada'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: (_sendingFacial || _facialBytes == null) ? null : _submitFacial,
            icon: _sendingFacial
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Salvar foto facial'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
