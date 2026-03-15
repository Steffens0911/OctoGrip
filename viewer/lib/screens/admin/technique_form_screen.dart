import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/searchable_dropdown.dart';

class TechniqueFormScreen extends StatefulWidget {
  final String academyId;
  final Technique? technique;

  const TechniqueFormScreen({super.key, required this.academyId, this.technique});

  @override
  State<TechniqueFormScreen> createState() => _TechniqueFormScreenState();
}

class _TechniqueFormScreenState extends State<TechniqueFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormBuilderState>();
  List<Position> _positions = [];
  List<Technique> _allTechniques = [];
  bool _loadingPositions = true;
  bool _loadingTechniques = true;
  bool _saving = false;
  String? _error;
  String _nameQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPositions();
    _loadTechniques();
  }

  Future<void> _loadPositions() async {
    try {
      final list = await _api.getPositions(academyId: widget.academyId);
      if (mounted) setState(() {
        _positions = list..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _loadingPositions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPositions = false);
    }
  }

  Future<void> _loadTechniques() async {
    try {
      final list = await _api.getTechniques(academyId: widget.academyId);
      if (mounted) {
        setState(() {
          _allTechniques = list..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          _loadingTechniques = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTechniques = false);
    }
  }

  List<Technique> get _filteredTechniques {
    final q = _nameQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _allTechniques.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final name = values['name'] as String;
      final nameTrimmed = name.trim();
      final videoUrl = values['videoUrl'] as String?;
      final description = values['description'] as String?;
      final fromPositionId = values['fromPositionId'] as String;
      final toPositionId = values['toPositionId'] as String;

      // Verificar possível duplicata ao criar nova técnica
      if (widget.technique == null && nameTrimmed.isNotEmpty && _allTechniques.isNotEmpty) {
        final hasDuplicate = _allTechniques.any(
          (t) => t.name.toLowerCase().trim() == nameTrimmed.toLowerCase(),
        );
        if (hasDuplicate) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Técnica já existe'),
              content: Text('Já existe uma técnica chamada "$nameTrimmed".\n\nDeseja criar mesmo assim?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Criar mesmo assim'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }
      }

      setState(() { _saving = true; _error = null; });
      try {
        if (widget.technique == null) {
          await _api.createTechnique(
            academyId: widget.academyId,
            name: nameTrimmed,
            videoUrl: videoUrl?.trim().isEmpty == true ? null : videoUrl?.trim(),
            description: description?.trim().isEmpty == true ? null : description?.trim(),
            fromPositionId: fromPositionId,
            toPositionId: toPositionId,
          );
        } else {
          await _api.updateTechnique(
            widget.technique!.id,
            academyId: widget.academyId,
            name: nameTrimmed,
            videoUrl: videoUrl?.trim().isEmpty == true ? null : videoUrl?.trim(),
            description: description?.trim().isEmpty == true ? null : description?.trim(),
            fromPositionId: fromPositionId,
            toPositionId: toPositionId,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) setState(() { _error = userFacingMessage(e); _saving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.technique == null ? 'Nova técnica' : 'Editar técnica'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'name': widget.technique?.name ?? '',
            'videoUrl': widget.technique?.videoUrl ?? '',
            'description': widget.technique?.description ?? '',
            'fromPositionId': widget.technique?.fromPositionId,
            'toPositionId': widget.technique?.toPositionId,
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex: Arm lock na montada',
                  helperText: 'Digite para ver técnicas similares já cadastradas',
                ),
                onChanged: (v) {
                  setState(() {
                    _nameQuery = (v ?? '').toString();
                  });
                },
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'Nome é obrigatório'),
                ]),
              ),
              if (_nameQuery.trim().isNotEmpty && _filteredTechniques.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: AppRadius.chipRadius,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Técnicas encontradas (${_filteredTechniques.length}):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._filteredTechniques.take(5).map(
                        (t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_filteredTechniques.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '... e mais ${_filteredTechniques.length - 5}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'videoUrl',
                decoration: const InputDecoration(labelText: 'Link do YouTube (opcional)'),
                keyboardType: TextInputType.url,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.url(errorText: 'URL inválida'),
                ]),
              ),
              const SizedBox(height: 16),
              if (_loadingPositions)
                const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
              else ...[
                SearchableDropdown<Position>(
                  name: 'fromPositionId',
                  labelText: 'De posição',
                  items: _positions,
                  getLabel: (p) => p.name,
                  getValue: (p) => p.id,
                  initialValue: widget.technique?.fromPositionId,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Selecione a posição de origem'),
                  ]),
                ),
                const SizedBox(height: 16),
                SearchableDropdown<Position>(
                  name: 'toPositionId',
                  labelText: 'Para posição',
                  items: _positions,
                  getLabel: (p) => p.name,
                  getValue: (p) => p.id,
                  initialValue: widget.technique?.toPositionId,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Selecione a posição de destino'),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'description',
                decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                maxLines: 2,
              ),
              if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
