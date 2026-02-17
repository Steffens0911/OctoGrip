import 'package:flutter/material.dart';
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
  final _nameCtrl = TextEditingController();
  List<Technique> _techniques = [];
  List<Lesson> _lessons = [];
  String? _weeklyTechniqueId;
  String? _visibleLessonId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.academy != null) {
      _nameCtrl.text = widget.academy!.name;
      _weeklyTechniqueId = widget.academy!.weeklyTechniqueId;
      _visibleLessonId = widget.academy!.visibleLessonId;
    }
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
        if (_weeklyTechniqueId == null && widget.academy?.weeklyTechniqueId != null) {
          _weeklyTechniqueId = widget.academy!.weeklyTechniqueId;
        }
        if (_visibleLessonId == null && widget.academy?.visibleLessonId != null) {
          _visibleLessonId = widget.academy!.visibleLessonId;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nome é obrigatório');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.academy == null) {
        await _api.createAcademy(name: _nameCtrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academia criada')));
          Navigator.pop(context);
        }
      } else {
        await _api.updateAcademy(
          widget.academy!.id,
          name: _nameCtrl.text.trim(),
          weeklyTechniqueId: _weeklyTechniqueId,
          visibleLessonId: _visibleLessonId,
          updateVisibleLesson: true,
        );
        if (mounted) {
          final msg = _weeklyTechniqueId != null
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  // Tema da semana e lição visível só ao editar (nova academia = só nome)
                  if (isEdit) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _weeklyTechniqueId,
                      decoration: const InputDecoration(
                        labelText: 'Tema da semana (missão do dia)',
                        hintText: 'Selecione a técnica para todos os alunos',
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                        ..._techniques.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: (v) => setState(() => _weeklyTechniqueId = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A técnica selecionada aparecerá como missão do dia para todos os alunos desta academia.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _visibleLessonId,
                      decoration: const InputDecoration(
                        labelText: 'Lição visível para o aluno',
                        hintText: 'Selecione a lição em destaque',
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                        ..._lessons.map((l) => DropdownMenuItem(value: l.id, child: Text(l.title))),
                      ],
                      onChanged: (v) => setState(() => _visibleLessonId = v),
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
    );
  }
}
