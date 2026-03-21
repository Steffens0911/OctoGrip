import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_providers.dart';

/// Bottom sheet: cria técnica via API e recarrega a lista (cache limpo após sucesso).
/// Campos opcionais alinhados ao `createTechnique` da API.
class TechniqueQuickCreateSheet extends ConsumerStatefulWidget {
  const TechniqueQuickCreateSheet({
    super.key,
    required this.academyId,
    this.onRequestFullForm,
  });

  final String academyId;
  final VoidCallback? onRequestFullForm;

  static Future<void> show(
    BuildContext context, {
    required String academyId,
    VoidCallback? onRequestFullForm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => TechniqueQuickCreateSheet(
        academyId: academyId,
        onRequestFullForm: onRequestFullForm,
      ),
    );
  }

  @override
  ConsumerState<TechniqueQuickCreateSheet> createState() =>
      _TechniqueQuickCreateSheetState();
}

class _TechniqueQuickCreateSheetState
    extends ConsumerState<TechniqueQuickCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final notifier = ref.read(
      techniqueListNotifierProvider(widget.academyId).notifier,
    );

    final desc = _descCtrl.text.trim();
    final video = _videoCtrl.text.trim();

    final result = await notifier.createOptimistic(
      name: _nameCtrl.text,
      description: desc.isEmpty ? null : desc,
      videoUrl: video.isEmpty ? null : video,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message)),
        );
      },
      (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Técnica criada'),
            backgroundColor: AppTheme.primary,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final mutationBusy = ref
        .watch(techniqueListNotifierProvider(widget.academyId))
        .mutationInProgress;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nova técnica',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Criação rápida — após salvar, a lista é atualizada a partir do servidor.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  hintText: 'Ex.: Arm Lock da guarda fechada',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nome obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _videoCtrl,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'URL do vídeo (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: (_submitting || mutationBusy) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar agora'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onRequestFullForm?.call();
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Formulário completo (mais campos)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
