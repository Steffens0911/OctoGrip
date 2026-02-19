import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

class AcademyFormScreen extends StatefulWidget {
  final Academy? academy;

  const AcademyFormScreen({super.key, this.academy});

  @override
  State<AcademyFormScreen> createState() => _AcademyFormScreenState();
}

class _AcademyFormScreenState extends State<AcademyFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormBuilderState>();
  List<Technique> _techniques = [];
  List<Lesson> _lessons = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.academy == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.getTechniques(academyId: widget.academy!.id),
        _api.getLessons(academyId: widget.academy!.id),
      ]);
      if (mounted) setState(() {
        _techniques = results[0] as List<Technique>;
        _lessons = results[1] as List<Lesson>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final name = values['name'] as String;
      final weeklyTechniqueId = values['weeklyTechniqueId'] as String?;
      final visibleLessonId = values['visibleLessonId'] as String?;
      
      setState(() {
        _saving = true;
        _error = null;
      });
      try {
        if (widget.academy == null) {
          await _api.createAcademy(name: name.trim());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academia criada')));
            Navigator.pop(context);
          }
        } else {
          await _api.updateAcademy(
            widget.academy!.id,
            name: name.trim(),
            weeklyTechniqueId: weeklyTechniqueId,
            visibleLessonId: visibleLessonId,
            updateVisibleLesson: true,
          );
          if (mounted) {
            final msg = weeklyTechniqueId != null
                ? 'Academia atualizada. Missão do dia definida para todos os alunos.'
                : 'Academia atualizada';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) setState(() { _error = userFacingMessage(e); _saving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.academy != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar academia' : 'Nova academia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading && isEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FormBuilder(
                key: _formKey,
                initialValue: {
                  'name': widget.academy?.name ?? '',
                  'weeklyTechniqueId': widget.academy?.weeklyTechniqueId,
                  'visibleLessonId': widget.academy?.visibleLessonId,
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
                    // Tema da semana e lição visível só ao editar (nova academia = só nome)
                    if (isEdit) ...[
                      const SizedBox(height: 16),
                      FormBuilderDropdown<String>(
                        name: 'weeklyTechniqueId',
                        decoration: const InputDecoration(
                          labelText: 'Tema da semana (missão do dia)',
                          hintText: 'Selecione a técnica para todos os alunos',
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                          ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                        ],
                        initialValue: widget.academy?.weeklyTechniqueId,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A técnica selecionada aparecerá como missão do dia para todos os alunos desta academia.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FormBuilderDropdown<String>(
                        name: 'visibleLessonId',
                        decoration: const InputDecoration(
                          labelText: 'Lição visível para o aluno',
                          hintText: 'Selecione a lição em destaque',
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                          ..._lessons.map((l) => DropdownMenuItem(value: l.id, child: Text(l.title))),
                        ],
                        initialValue: widget.academy?.visibleLessonId,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A lição selecionada aparecerá em destaque na biblioteca do aluno.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
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
