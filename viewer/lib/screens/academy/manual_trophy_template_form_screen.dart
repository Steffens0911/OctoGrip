import 'package:flutter/material.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/manual_trophy.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Formulário para criar ou editar um template de troféu manual.
class ManualTrophyTemplateFormScreen extends StatefulWidget {
  const ManualTrophyTemplateFormScreen({
    super.key,
    required this.academyId,
    required this.trophyType,
    this.existing,
  });

  final String academyId;
  final String trophyType; // 'custom' | 'championship'
  final TrophyTemplate? existing;

  @override
  State<ManualTrophyTemplateFormScreen> createState() =>
      _ManualTrophyTemplateFormScreenState();
}

class _ManualTrophyTemplateFormScreenState
    extends State<ManualTrophyTemplateFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;
  bool get _isChampionship => widget.trophyType == 'championship';

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _nameCtrl.text = t.name;
      _descCtrl.text = t.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await _api.updateManualTrophyTemplate(
          widget.existing!.id,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
        );
      } else {
        await _api.createManualTrophyTemplate(
          academyId: widget.academyId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          trophyType: widget.trophyType,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception:?\s*'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? 'Editar troféu'
        : _isChampionship
            ? 'Novo modelo de medalha'
            : 'Novo troféu';

    return Scaffold(
      appBar: AppStandardAppBar(title: title),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            // Dica contextual
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(
                _isChampionship
                    ? 'Modelos de medalha são usados para premiar alunos em campeonatos reais. '
                        'Exemplos: "Medalha IBJJF", "Medalha Estadual".'
                    : 'Troféus livres podem ser concedidos a qualquer aluno a qualquer momento. '
                        'Exemplos: "Troféu Pontualidade", "Aluno Destaque do Mês".',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: _isChampionshipHint,
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nome obrigatório';
                if (v.trim().length > 255) return 'Máximo 255 caracteres';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.m),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Ex: Para quem nunca faltou no mês',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.m),
              Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Salvar alterações' : 'Criar troféu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: constant_identifier_names
const _isChampionshipHint = 'Ex: Troféu Pontualidade';
