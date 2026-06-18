import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/marketplace_item.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class MarketplaceFormScreen extends StatefulWidget {
  final MarketplaceItem? item;

  const MarketplaceFormScreen({super.key, this.item});

  @override
  State<MarketplaceFormScreen> createState() => _MarketplaceFormScreenState();
}

class _MarketplaceFormScreenState extends State<MarketplaceFormScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _dddCtrl = TextEditingController();
  final _phoneLocalCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();
  final _academyIdCtrl = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  /// URL da imagem atual (já salva no servidor ou recém-enviada).
  String? _imageUrl;
  /// Bytes da imagem selecionada localmente (ainda não enviada).
  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _titleCtrl.text = it.title;
      if (it.description != null) _descCtrl.text = it.description!;
      _priceCtrl.text =
          (it.priceCents / 100).toStringAsFixed(2).replaceAll('.', ',');
      if (it.whatsappDdd != null && it.whatsappDdd!.isNotEmpty) {
        _dddCtrl.text = it.whatsappDdd!;
      }
      if (it.whatsappNumber != null && it.whatsappNumber!.isNotEmpty) {
        _phoneLocalCtrl.text = it.whatsappNumber!;
      }
      if (it.sortOrder != null) _sortCtrl.text = it.sortOrder.toString();
      _isActive = it.isActive;
      if (it.academyId != null) _academyIdCtrl.text = it.academyId!;
      _imageUrl = it.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _dddCtrl.dispose();
    _phoneLocalCtrl.dispose();
    _sortCtrl.dispose();
    _academyIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pendingImageBytes = bytes;
      _pendingImageName = picked.name;
    });
  }

  void _removeImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageName = null;
      _imageUrl = null;
    });
  }

  int? _parsePriceCents() {
    final raw = _priceCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw);
    if (v == null || v < 0) return null;
    return (v * 100).round();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Informe o título do produto.');
      return;
    }
    final cents = _parsePriceCents();
    if (cents == null) {
      setState(() => _error = 'Informe um preço válido (ex.: 199,90).');
      return;
    }
    final isAdmin = AuthService().isAdmin();
    final academyIdField = _academyIdCtrl.text.trim();
    if (widget.item == null && isAdmin && academyIdField.isEmpty) {
      setState(
          () => _error = 'Administrador deve informar o ID da academia (UUID).');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // Upload da imagem pendente antes de salvar o anúncio
    String? finalImageUrl = _imageUrl;
    if (_pendingImageBytes != null) {
      setState(() => _uploadingImage = true);
      try {
        finalImageUrl = await _api.uploadMarketplaceImage(
          bytes: _pendingImageBytes!,
          filename: _pendingImageName ?? 'product.jpg',
        );
        setState(() {
          _imageUrl = finalImageUrl;
          _pendingImageBytes = null;
          _pendingImageName = null;
          _uploadingImage = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _uploadingImage = false;
          _error = 'Falha ao enviar imagem: ${userFacingMessage(e)}';
        });
        return;
      }
    }

    final desc = _descCtrl.text.trim();
    final sort = int.tryParse(_sortCtrl.text.trim());
    final ddd = _dddCtrl.text.trim();
    final local = _phoneLocalCtrl.text.trim();

    try {
      if (widget.item == null) {
        await _api.createMarketplaceItem(
          title: title,
          description: desc.isEmpty ? null : desc,
          priceCents: cents,
          imageUrl: finalImageUrl,
          whatsappDdd: ddd.isEmpty ? null : ddd,
          whatsappNumber: local.isEmpty ? null : local,
          sortOrder: sort,
          isActive: _isActive,
          academyId:
              isAdmin && academyIdField.isNotEmpty ? academyIdField : null,
        );
      } else {
        await _api.updateMarketplaceItem(
          id: widget.item!.id,
          title: title,
          description: desc.isEmpty ? null : desc,
          priceCents: cents,
          imageUrl: finalImageUrl,
          whatsappDdd: ddd.isEmpty ? null : ddd,
          whatsappNumber: local.isEmpty ? null : local,
          sortOrder: sort,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: 'Anúncio salvo.',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Widget _buildImagePicker(BuildContext context) {
    final serverBase = _api.baseUrl;

    // Preview: imagem selecionada localmente
    if (_pendingImageBytes != null) {
      return _ImagePreviewBox(
        onRemove: _saving ? null : _removeImage,
        onReplace: _saving ? null : _pickImage,
        child: Image.memory(_pendingImageBytes!, fit: BoxFit.cover),
      );
    }

    // Preview: imagem já salva no servidor
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      final resolved = _imageUrl!.startsWith('/')
          ? '$serverBase${_imageUrl!}'
          : _imageUrl!;
      return _ImagePreviewBox(
        onRemove: _saving ? null : _removeImage,
        onReplace: _saving ? null : _pickImage,
        child: Image.network(resolved, fit: BoxFit.cover),
      );
    }

    // Placeholder — toca para selecionar
    return GestureDetector(
      onTap: _saving ? null : _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_photo_alternate_outlined,
                size: 40, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              'Adicionar foto do produto',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService().isAdmin();
    final isNew = widget.item == null;

    return Scaffold(
      appBar: AppStandardAppBar(
        title: isNew ? 'Novo anúncio' : 'Editar anúncio',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ),
            if (isNew && isAdmin) ...[
              TextField(
                controller: _academyIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'ID da academia (UUID)',
                  hintText: 'Obrigatório para administrador',
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Imagem do produto
            Text(
              'Foto do produto',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (_uploadingImage)
              Container(
                height: 160,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              )
            else
              _buildImagePicker(context),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preço (R\$)',
                hintText: '199,90',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'WhatsApp (opcional)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'DDD e número (só dígitos). A mensagem enviada ao abrir o WhatsApp é definida pelo app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: _dddCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: 'DDD',
                      hintText: '11',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _phoneLocalCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 9,
                    decoration: const InputDecoration(
                      labelText: 'Número',
                      hintText: '999999999',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ordem de exibição (opcional)',
                hintText: 'Menor aparece primeiro',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Ativo (visível para alunos)'),
              value: _isActive,
              onChanged:
                  _saving ? null : (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRemove;
  final VoidCallback? onReplace;

  const _ImagePreviewBox({
    required this.child,
    this.onRemove,
    this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: child,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            children: [
              _iconBtn(
                icon: Icons.edit,
                tooltip: 'Trocar foto',
                onTap: onReplace,
              ),
              const SizedBox(width: 4),
              _iconBtn(
                icon: Icons.delete_outline,
                tooltip: 'Remover foto',
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
