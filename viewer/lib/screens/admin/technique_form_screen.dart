import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

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
  bool _loadingPositions = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    try {
      final list = await _api.getPositions(academyId: widget.academyId);
      if (mounted) setState(() {
        _positions = list;
        _loadingPositions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPositions = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final name = values['name'] as String;
      final videoUrl = values['videoUrl'] as String?;
      final description = values['description'] as String?;
      final fromPositionId = values['fromPositionId'] as String;
      final toPositionId = values['toPositionId'] as String;
      
      setState(() { _saving = true; _error = null; });
      try {
        if (widget.technique == null) {
          await _api.createTechnique(
            academyId: widget.academyId,
            name: name.trim(),
            videoUrl: videoUrl?.trim().isEmpty == true ? null : videoUrl?.trim(),
            description: description?.trim().isEmpty == true ? null : description?.trim(),
            fromPositionId: fromPositionId,
            toPositionId: toPositionId,
          );
        } else {
          await _api.updateTechnique(
            widget.technique!.id,
            academyId: widget.academyId,
            name: name.trim(),
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
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'Nome é obrigatório'),
                ]),
              ),
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
                FormBuilderDropdown<String>(
                  name: 'fromPositionId',
                  decoration: const InputDecoration(labelText: 'De posição'),
                  items: _positions.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  initialValue: widget.technique?.fromPositionId,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'Selecione a posição de origem'),
                  ]),
                ),
                const SizedBox(height: 16),
                FormBuilderDropdown<String>(
                  name: 'toPositionId',
                  decoration: const InputDecoration(labelText: 'Para posição'),
                  items: _positions.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
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
